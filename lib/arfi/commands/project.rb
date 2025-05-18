# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    # +Arfi::Commands::Project+ class is used to create `db/functions` directory.
    class Project < Thor
      desc 'create', 'Initialize project by creating db/functions directory' # steep:ignore NoMethod
      # +Arfi::Commands::Project#create+                 -> void
      #
      # This command is used to create `db/functions` directory.
      #
      # @example
      #   bundle exec arfi project create
      # @return [void]
      # @raise [Arfi::Errors::InvalidSchemaFormat] if ActiveRecord.schema_format is not :ruby.
      def create
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby # steep:ignore NoMethod
        return puts "Directory #{functions_dir} already exists" if Dir.exist?(functions_dir)

        FileUtils.mkdir_p(functions_dir)
        puts "Created: #{functions_dir}"
      end

      private

      # +Arfi::Commands::Project#functions_dir+ -> Pathname
      #
      # Helper method to get path to `db/functions` directory.
      #
      # @!visibility private
      # @private
      # @return [Pathname] Path to `db/functions` directory
      def functions_dir
        Rails.root.join('db/functions')
      end
    end
  end
end
