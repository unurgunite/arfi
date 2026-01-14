# frozen_string_literal: true

require 'thor'
require 'rails'
require 'fileutils'
require File.expand_path('config/environment', Dir.pwd)

module Arfi
  module Commands
    class FIdx < Thor
      ADAPTERS = %i[postgresql mysql].freeze
      ROOT_DIR = 'db/functions'

      # steep:ignore:start
      desc 'create FUNCTION_NAME [--template=template_file --adapter=adapter --force]',
           'Create (or overwrite with --force) a SQL function file at db/functions[/adapter]/FUNCTION_NAME.sql'
      option :template, type: :string, banner: 'template_file',
                        desc: 'Path to the template file. See `README.md` for details.'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :force, type: :boolean, default: false,
                     desc: 'Overwrite existing FUNCTION_NAME.sql if it already exists.'
      # steep:ignore:end
      def create(index_name)
        validate_schema_format!
        validate_function_name!(index_name)
        ensure_functions_dir!

        content = build_sql_function(index_name)
        write_function_file(index_name, content)
      end

      # steep:ignore:start
      desc 'destroy FUNCTION_NAME [--adapter=adapter]', 'Delete db/functions[/adapter]/FUNCTION_NAME.sql'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end
      def destroy(index_name)
        validate_schema_format!
        validate_function_name!(index_name)
        ensure_functions_dir!

        path = function_path(index_name)
        unless File.exist?(path)
          puts "Not found: #{path}"
          return
        end

        FileUtils.rm(path)
        puts "Deleted: #{path}"
      end

      private

      def validate_schema_format!
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby # steep:ignore NoMethod
      end

      # Prevent path traversal / nested paths / weird names.
      # You can loosen this later if you want schema-qualified names, but then you should map
      # schema to a filename safely (e.g., public.my_fn -> public__my_fn.sql).
      def validate_function_name!(name)
        raise ArgumentError, "Invalid function name: #{name.inspect}" unless name.is_a?(String)

        sep = [File::SEPARATOR, File::ALT_SEPARATOR].compact
        bad = name.empty? || name.include?('..') || sep.any? { |s| name.include?(s) }

        raise ArgumentError, "Invalid function name: #{name.inspect}" if bad
      end

      def ensure_functions_dir!
        root = Rails.root.join(ROOT_DIR)

        # The "project initialized?" check should be on db/functions, not the adapter subdir.
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        # If adapter was specified, ensure the adapter subdir exists (create it on demand).
        dir = functions_dir
        FileUtils.mkdir_p(dir) unless dir.directory?
      end

      def build_sql_function(index_name)
        return build_from_file(index_name) if options[:template] # steep:ignore NoMethod

        adapter = options[:adapter] # steep:ignore NoMethod

        # Default / postgresql skeleton
        return <<~SQL if adapter.nil? || adapter == 'postgresql'
          CREATE OR REPLACE FUNCTION #{index_name}() RETURNS TEXT[]
              LANGUAGE SQL
              IMMUTABLE AS
          $$
              -- Function body here
          $$
        SQL

        case adapter
        when 'mysql'
          <<~SQL
            -- MySQL note: you may need to DROP FUNCTION IF EXISTS #{index_name};
            -- and ensure your connection allows multi-statements if you include both.
            CREATE FUNCTION #{index_name} ()
            RETURNS return_type
            BEGIN
              -- Function body here
            END;
          SQL
        else
          raise "Unknown adapter: #{adapter}. Supported adapters: #{ADAPTERS.join(', ')}"
        end
      end

      def build_from_file(index_name)
        # steep:ignore:start
        RubyVM::InstructionSequence
          .compile("index_name = '#{index_name}'; #{File.read(options[:template])}")
          .eval
        # steep:ignore:end
      end

      def write_function_file(index_name, content)
        path = function_path(index_name)

        if File.exist?(path) && !options[:force] # steep:ignore NoMethod
          puts "Already exists: #{path} (use --force to overwrite)"
          return
        end

        File.write(path, content.to_s)
        puts "Created: #{path}"
      end

      def function_path(index_name)
        functions_dir.join("#{index_name}.sql").to_s
      end

      def functions_dir
        validate_adapter_option!
        root = Rails.root.join(ROOT_DIR)
        # steep:ignore:start
        return root.join(options[:adapter].to_s) if options[:adapter]

        root
      end

      def validate_adapter_option!
        return unless options[:adapter] # steep:ignore NoMethod
        # steep:ignore NoMethod
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(options[:adapter].to_sym)
      end
      # steep:ignore:end
    end
  end
end
