# frozen_string_literal: true

require 'thor'
require 'rails'
require 'fileutils'
require 'json'

require_relative 'triggers_helpers'
require_relative 'triggers_creation'
require_relative 'triggers_paths'
require_relative 'triggers_rendering'
require_relative 'triggers_candidates'
require_relative 'triggers_doctor_rendering'
require_relative 'triggers_doctor'

module Arfi
  module Commands
    TRIGGERS_ROOT_DIR = 'db/triggers'

    # Thor CLI for managing SQL trigger files.
    class Triggers < Thor
      include TriggersHelpers
      include TriggersCreation
      include TriggersPaths
      include TriggersRendering
      include TriggersCandidates
      include TriggersDoctor

      default_task :list

      map %w[ls] => :list
      map %w[rm delete del] => :destroy
      map %w[new add] => :create

      # steep:ignore:start
      desc(
        'create TRIGGER_NAME [--table=table --event=event --timing=timing ' \
        '--for-each=row|statement --function=function --schema=schema ' \
        '--template=template_file --adapter=adapter --force]',
        "Create (or overwrite with --force) a SQL trigger file.\n  " \
        "Generic public:      db/triggers/public/<trigger>.sql\n  " \
        "PostgreSQL public:   db/triggers/postgresql/public/<trigger>.sql\n  " \
        "PostgreSQL schema:   db/triggers/postgresql/<schema>/<trigger>.sql\n" \
        "Schema can be passed as 'schema.trigger' or via --schema (PostgreSQL only)."
      )
      option :table, type: :string, banner: 'table',
                     desc: 'Table name the trigger fires on (required).'
      option :event, type: :string, repeatable: true, banner: 'event',
                     desc: 'Trigger event: INSERT, UPDATE, DELETE (repeatable for multiple events).'
      option :timing, type: :string, banner: 'timing',
                      desc: 'Trigger timing: BEFORE, AFTER, INSTEAD OF.'
      option :'for-each', type: :string, banner: 'for_each',
                          desc: 'Trigger scope: ROW or STATEMENT.'
      option :function, type: :string, banner: 'function',
                        desc: 'Trigger function name (PostgreSQL only).'
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.trigger')."
      option :template, type: :string, banner: 'template_file',
                        desc: 'Path to the template file. See README.md for details.'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :force, type: :boolean, default: false,
                     desc: 'Overwrite existing trigger file if it already exists.'
      # steep:ignore:end
      # Creates a SQL trigger file in db/triggers.
      #
      # Supports --table, --event, --timing, --for-each, --function, --schema,
      # --template, --adapter, and --force options.
      #
      # @param [String] trigger_ref name or schema.name of the trigger
      # @return [void]
      def create(trigger_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, trigger_name = parse_trigger_ref(trigger_ref)
        validate_identifiers!(schema, trigger_name)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        content = build_sql_trigger(schema, trigger_name, original_ref: trigger_ref)
        write_file(schema, trigger_name, content)
      end

      # steep:ignore:start
      desc(
        'destroy TRIGGER_NAME [--schema=schema --adapter=adapter]',
        'Delete a SQL trigger file (supports both new and legacy locations).'
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.trigger')."
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end
      # Deletes a SQL trigger file from db/triggers.
      #
      # Searches all candidate locations (legacy and new) for the file.
      #
      # @param [String] trigger_ref name or schema.name of the trigger
      # @return [void]
      def destroy(trigger_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, trigger_name = parse_trigger_ref(trigger_ref)
        validate_identifiers!(schema, trigger_name)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        remove_trigger_file(schema, trigger_name)
      end

      # steep:ignore:start
      desc(
        'list [--adapter=adapter] [--format=table|paths|json] [--all]',
        "List SQL trigger files ARFI would load for the chosen adapter.\n" \
        "Default: inferred adapter from Rails config. Default output: table.\n" \
        '--all shows shadowed/overridden candidates too.'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      option :all, type: :boolean, default: false,
                   desc: 'Show all candidates (including overridden ones), not just the effective set.'
      # steep:ignore:end
      # Lists trigger SQL files ARFI would load for the chosen adapter.
      #
      # Supports --adapter, --format (table|paths|json), and --all flags.
      #
      # @return [void]
      def list
        validate_schema_format!
        validate_adapter_option!

        adapter = resolve_adapter
        rows = resolve_triggers_for(adapter: adapter)

        render_list(rows)
      end

      # steep:ignore:start
      desc(
        'validate [--adapter=adapter] [--format=table|paths|json]',
        "Validate SQL trigger files by running them against the database.\n" \
        "On PostgreSQL, runs inside a transaction that is rolled back.\n" \
        'On MySQL/Trilogy, triggers are loaded as a side effect.'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      # steep:ignore:end
      # Validate all SQL trigger files by executing them against the database.
      #
      # Delegates to {TriggersDoctor#validate}. On PostgreSQL, each file runs
      # inside a transaction that is rolled back. On MySQL/Trilogy, DDL commits.
      #
      # @return [void]
      def validate # rubocop:disable Lint/UselessMethodDefinition
        super
      end

      # steep:ignore:start
      desc(
        'doctor [--adapter=adapter] [--format=table|paths|json]',
        "Check trigger status: compare files on disk vs the database.\n" \
        'Shows each resolved trigger as OK (exists) or MISSING (not in DB).'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      # steep:ignore:end
      # Compare trigger files on disk vs the database and report discrepancies.
      #
      # Delegates to {TriggersDoctor#doctor}. Shows each resolved trigger as OK
      # (exists in DB) or MISSING (file on disk but not loaded).
      #
      # @return [void]
      def doctor # rubocop:disable Lint/UselessMethodDefinition
        super
      end
    end
  end
end
