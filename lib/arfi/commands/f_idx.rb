# frozen_string_literal: true

require 'thor'

module Arfi
  module Commands
    class FIdx < Thor
      desc 'create INDEX_NAME', 'Initialize the functional index'

      def create(index_name)
        unless defined?(Rails) && Rails.respond_to?(:root)
          puts 'Error: Rails is not loaded. Are you running this inside a Rails project?'
          exit(1)
        end

        functions_dir = Rails.root.join('db/functions')
        content = <<~SQL
          CREATE OR REPLACE FUNCTION #{index_name} RETURNS TEXT[]
            LANGUAGE SQL
            IMMUTABLE AS
          $$
        SQL
        if (sql_fidx_files = Dir.glob("#{functions_dir}/#{index_name}*.sql"))
          if (file = sql_fidx_files.map { File.basename(_1) }.max).match?(/\w+_v(\d+)\.sql/)
            index = file.match(/\w+_v(\d+)\.sql/)[1]
            File.write("#{functions_dir}_v#{index.next}.sql", content)
          end
        else
          File.write("#{functions_dir}/#{index_name}_v01.sql", content)
        end

        puts "Created: #{functions_dir}"
      end

      def destroy(index_name, revision: 1)
        unless defined?(Rails) && Rails.respond_to?(:root)
          puts 'Error: Rails is not loaded. Are you running this inside a Rails project?'
          exit(1)
        end

        functions_dir = Rails.root.join('db/functions')
        FileUtils.rm("#{functions_dir}/#{index_name}_v#{revision}.sql")

        puts "Deleted: #{functions_dir}/#{index_name}_v#{revision}.sql"
      end
    end
  end
end
