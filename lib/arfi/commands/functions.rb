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

      default_task :list

      # UX aliases
      map %w[ls] => :list
      map %w[rm delete del] => :destroy
      map %w[new add] => :create

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
    end
  end
end
