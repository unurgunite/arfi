# frozen_string_literal: true

require 'thor'
require 'rails'
require File.expand_path('config/environment', Dir.pwd)

module Arfi
  module Commands
    class FIdx < Thor
      desc 'create INDEX_NAME', 'Initialize the functional index'
      def create(index_name)
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby

        content = <<~SQL
          CREATE OR REPLACE FUNCTION #{index_name}() RETURNS TEXT[]
              LANGUAGE SQL
              IMMUTABLE AS
          $$
              -- Function body here
          $$
        SQL

        # Check if there is already index with the same name
        if (sql_fidx_files = Dir.glob("#{functions_dir}/#{index_name}*.sql")).empty?
          path = "#{functions_dir}/#{index_name}_v01.sql"
          File.write(path, content)
          puts "Created: #{path}"
        elsif (file = sql_fidx_files.map { File.basename(_1) }.max)&.match?(/\w+_v(\d+)\.sql/)
          # Get the last revision of custom SQL function
          index = file.match(/\w+_v(\d+)\.sql/)[1]
          path = "#{functions_dir}/#{index_name}_v#{index.next}.sql"
          File.write(path, content)
          puts "Created: #{path}"
        end
      rescue Errno::ENOENT
        raise Arfi::Errors::NoFunctionsDir, cause: nil
      end

      desc 'destroy INDEX_NAME [REVISION]', 'Delete the functional index'
      def destroy(index_name, revision = 1)
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby

        FileUtils.rm("#{functions_dir}/#{index_name}_v#{revision}.sql")
        puts "Deleted: #{functions_dir}/#{index_name}_v#{revision}.sql"
      end

      private

      def functions_dir
        Rails.root.join('db/functions')
      end
    end
  end
end
