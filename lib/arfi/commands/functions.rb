# frozen_string_literal: true

require 'thor'
require 'rails'
require 'fileutils'
require 'json'

require_relative 'functions_helpers'
require_relative 'functions_creation'
require_relative 'functions_paths'
require_relative 'functions_rendering'
require_relative 'functions_candidates'
require_relative 'functions_doctor_rendering'
require_relative 'functions_doctor'
require_relative 'functions_show'

module Arfi
  module Commands
    ADAPTERS = %i[postgresql mysql trilogy].freeze
    ROOT_DIR = 'db/functions'
    DEFAULT_SCHEMA = 'public'
    IDENT = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.freeze

    # Thor CLI for managing SQL function files.
    class Functions < Thor
      include FunctionsHelpers
      include FunctionsCreation
      include FunctionsPaths
      include FunctionsRendering
      include FunctionsCandidates
      include FunctionsDoctor
      include FunctionsShow

      default_task :list

      # UX aliases
      map %w[ls] => :list
      map %w[rm delete del] => :destroy
      map %w[new add] => :create
      map %w[show cat source] => :display_source

      # steep:ignore:start
      desc(
        'create FUNCTION_NAME [--schema=schema --template=template_file --adapter=adapter --force]',
        "Create (or overwrite with --force) a SQL function file.\n  " \
        "Generic public:      db/functions/public/<function>.sql\n  " \
        "PostgreSQL public:   db/functions/postgresql/public/<function>.sql\n  " \
        "PostgreSQL schema:   db/functions/postgresql/<schema>/<function>.sql\n" \
        "Schema can be passed as 'schema.function' or via --schema (PostgreSQL only)."
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.function')."
      option :template, type: :string, banner: 'template_file',
                        desc: 'Path to the template file. See README.md for details.'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :force, type: :boolean, default: false,
                     desc: 'Overwrite existing function file if it already exists.'
      # steep:ignore:end
      # Create (or overwrite with --force) a SQL function file in the appropriate directory.
      #
      # @param [String] function_ref Function reference string (e.g. 'my_func' or 'schema.my_func')
      # @return [void]
      def create(function_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, function_name = parse_function_ref(function_ref)
        validate_identifiers!(schema, function_name)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        content = build_sql_function(schema, function_name, original_ref: function_ref)
        write_file(schema, function_name, content)
      end

      # steep:ignore:start
      desc(
        'destroy FUNCTION_NAME [--schema=schema --adapter=adapter]',
        'Delete a SQL function file (supports both new and legacy locations).'
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.function')."
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end
      # Delete a SQL function file from disk (supports both new and legacy locations).
      #
      # @param [String] function_ref Function reference string (e.g. 'my_func' or 'schema.my_func')
      # @return [void]
      def destroy(function_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, function_name = parse_function_ref(function_ref)
        validate_identifiers!(schema, function_name)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        remove_function_file(schema, function_name)
      end

      # steep:ignore:start
      desc(
        'list [--adapter=adapter] [--format=table|paths|json] [--all]',
        "List SQL function files ARFI would load for the chosen adapter.\n" \
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
      # List SQL function files ARFI would load for the chosen adapter.
      #
      # @return [void]
      def list
        validate_schema_format!
        validate_adapter_option!

        adapter = resolve_adapter
        rows = resolve_functions_for(adapter: adapter)

        render_list(rows)
      end

      # steep:ignore:start
      desc(
        'validate [--adapter=adapter] [--format=table|paths|json]',
        "Validate SQL function files by running them against the database.\n" \
        "On PostgreSQL, runs inside a transaction that is rolled back.\n" \
        'On MySQL/Trilogy, functions are loaded as a side effect.'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      # steep:ignore:end
      # Validate all SQL function files by executing them against the database.
      #
      # On PostgreSQL, each file runs inside a transaction that is rolled back.
      # On MySQL/Trilogy, DDL auto-commits, so functions are loaded as a side effect.
      #
      # @return [void]
      def validate # rubocop:disable Lint/UselessMethodDefinition
        super
      end

      # steep:ignore:start
      desc(
        'doctor [--adapter=adapter] [--format=table|paths|json]',
        "Check function status: compare files on disk vs the database.\n" \
        'Shows each resolved function as OK (exists) or MISSING (not in DB).'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      # steep:ignore:end
      # Compare functions on disk vs the database and report discrepancies.
      #
      # @return [void]
      def doctor # rubocop:disable Lint/UselessMethodDefinition
        super
      end

      # steep:ignore:start
      desc(
        'show FUNCTION_NAME [--schema=schema]',
        "Display the SQL source of a function from the database.\n" \
        'Uses pg_get_functiondef on PostgreSQL, SHOW CREATE FUNCTION on MySQL/Trilogy.'
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.function')."
      # steep:ignore:end
      # Display the SQL source of a function from the database.
      #
      # Delegates to {FunctionsShow#display_source}.
      #
      # @param [String] function_ref Function name (optionally schema-qualified)
      # @return [void]
      def display_source(function_ref) # rubocop:disable Lint/UselessMethodDefinition
        super
      end
    end
  end
end
