# frozen_string_literal: true

require 'thor'
require 'rails'
require File.expand_path('config/environment', Dir.pwd)

module Arfi
  module Commands
    # +Arfi::Commands::FIdx+ module contains commands for manipulating functional index in Rails project.
    class FIdx < Thor
      desc 'create INDEX_NAME', 'Initialize the functional index' # steep:ignore NoMethod
      option :template, type: :string, banner: 'template_file' # steep:ignore NoMethod
      # +Arfi::Commands::FIdx#create+                        -> void
      #
      # This command is used to create the functional index.
      #
      # @example
      #   bundle exec arfi f_idx create some_function
      #
      # ARFI also supports the use of custom templates for SQL functions, but now there are some restrictions and rules
      # according to which it is necessary to describe the function. First, the function must be written in a
      # Ruby-compatible syntax: the file name is not so important, but the name for the function name must be
      # interpolated with the +index_name+ variable name, and the function itself must be placed in the HEREDOC
      # statement. Below is an example file.
      #
      # @example
      #   # ./template/my_custom_template
      #   <<~SQL
      #   CREATE OR REPLACE FUNCTION #{index_name}() RETURNS TEXT[]
      #     LANGUAGE SQL
      #     IMMUTABLE AS
      #   $$
      #     -- Function body here
      #   $$
      #   SQL
      #
      # To use a custom template, add the --template flag.
      #
      # @example
      #   bundle exec arfi f_idx create some_function --template ./template/my_custom_template
      #
      # @param index_name [String] Name of the index.
      # @return [void]
      # @raise [Arfi::Errors::InvalidSchemaFormat] if ActiveRecord.schema_format is not :ruby
      # @raise [Arfi::Errors::NoFunctionsDir] if there is no `db/functions` directory
      # @see Arfi::Commands::FIdx#validate_schema_format!
      def create(index_name)
        validate_schema_format!
        content = build_sql_function(index_name)
        create_index_file(index_name, content)
      end

      desc 'destroy INDEX_NAME [REVISION]', 'Delete the functional index' # steep:ignore NoMethod
      # +Arfi::Commands::FIdx#destroy+                        -> void
      #
      # This command is used to delete the functional index.
      #
      # @example
      #   bundle exec arfi f_idx destroy some_function [revision index (just an integer, 1 is by default)]
      # @param index_name [String] Name of the index.
      # @param revision [String] Revision of the index.
      # @return [void]
      # @raise [Arfi::Errors::InvalidSchemaFormat] if ActiveRecord.schema_format is not :ruby
      def destroy(index_name, revision = '01')
        validate_schema_format!

        revision = "0#{revision}" if revision.match?(/^\d$/)
        FileUtils.rm("#{functions_dir}/#{index_name}_v#{revision}.sql")
        puts "Deleted: #{functions_dir}/#{index_name}_v#{revision}.sql"
      end

      private

      # +Arfi::Commands::FIdx#functions_dir+                        -> Pathname
      #
      # Helper method to get path to `db/functions` directory.
      #
      # @!visibility private
      # @private
      # @return [Pathname] Path to `db/functions` directory
      def functions_dir
        Rails.root.join('db/functions')
      end

      # +Arfi::Commands::FIdx#validate_schema_format!+                        -> void
      #
      # Helper method to validate the schema format.
      #
      # @!visibility private
      # @private
      # @raise [Arfi::Errors::InvalidSchemaFormat] if ActiveRecord.schema_format is not :ruby.
      # @return [nil] if the schema format is valid.
      def validate_schema_format!
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby # steep:ignore NoMethod
      end

      # +Arfi::Commands::FIdx#build_sql_function+                        -> String
      #
      # Helper method to build the SQL function.
      #
      # @!visibility private
      # @private
      # @param index_name [String] Name of the index.
      # @return [String] SQL function body.
      def build_sql_function(index_name)
        return build_from_file(index_name) if options[:template] # steep:ignore NoMethod

        <<~SQL
          CREATE OR REPLACE FUNCTION #{index_name}() RETURNS TEXT[]
              LANGUAGE SQL
              IMMUTABLE AS
          $$
              -- Function body here
          $$
        SQL
      end

      # +Arfi::Commands::FIdx#build_from_file+                          -> String
      #
      # Helper method to build the SQL function. Used with flag `--template`.
      #
      # @!visibility private
      # @private
      # @param index_name [String] Name of the index.
      # @return [String] SQL function body.
      # @see Arfi::Commands::FIdx#create
      # @see Arfi::Commands::FIdx#build_sql_function
      def build_from_file(index_name)
        # steep:ignore:start
        RubyVM::InstructionSequence.compile("index_name = '#{index_name}'; #{File.read(options[:template])}").eval
        # steep:ignore:end
      end

      # +Arfi::Commands::FIdx#create_index_file+                        -> void
      #
      # Helper method to create the index file.
      #
      # @!visibility private
      # @private
      # @param index_name [String] Name of the index.
      # @param content [String] SQL function body.
      # @return [void]
      def create_index_file(index_name, content)
        existing_files = Dir.glob("#{functions_dir}/#{index_name}*.sql")

        return write_file(index_name, content, 1) if existing_files.empty?

        latest_version = extract_latest_version(existing_files)
        write_file(index_name, content, latest_version.succ)
      end

      # +Arfi::Commands::FIdx#extract_latest_version+                        -> Integer
      #
      # Helper method to extract the latest version of the index.
      #
      # @!visibility private
      # @private
      # @param files [Array<String>] List of files.
      # @return [String] Latest version of the index.
      def extract_latest_version(files)
        version_numbers = files.map do |file|
          File.basename(file)[/\w+_v(\d+)\.sql/, 1]
        end.compact

        version_numbers.max
      end

      # +Arfi::Commands::FIdx#write_file+                        -> void
      #
      # Helper method to write the index file.
      #
      # @!visibility private
      # @private
      # @param index_name [String] Name of the index.
      # @param content [String] SQL function body.
      # @param version [String|Integer] Version of the index.
      # @return [void]
      def write_file(index_name, content, version)
        version_str = format('%02d', version)
        path = "#{functions_dir}/#{index_name}_v#{version_str}.sql"
        File.write(path, content.to_s)
        puts "Created: #{path}"
      end
    end
  end
end
