# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    class Project < Thor
      desc 'create', 'Initialize project by creating db/functions directory'
      def create
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby
        return puts "Directory #{functions_dir} already exists" if Dir.exist?(functions_dir)

        FileUtils.mkdir_p(functions_dir)
        puts "Created: #{functions_dir}"
      end

      private

      def functions_dir
        Rails.root.join('db/functions')
      end
    end
  end
end
