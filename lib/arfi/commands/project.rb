# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    # +Arfi::Commands::Project+ class is used to create `db/functions` directory.
    class Project < Thor
      ADAPTERS = %i[postgresql mysql].freeze

      # steep:ignore:start
      desc 'create', 'Initialize project by creating db/functions directory'
      option :adapter, type: :string,
                       desc: 'Specify database adapter, used for projects with multiple database architecture. ' \
                             "Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end

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

      # +Arfi::Commands::Project#functions_dir+          -> Pathname
      #
      # Helper method to get path to `db/functions` directory.
      #
      # @!visibility private
      # @private
      # @return [Pathname] Path to `db/functions` directory
      def functions_dir
        # steep:ignore:start
        if options[:adapter]
          raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(options[:adapter].to_sym)

          Rails.root.join("db/functions/#{options[:adapter]}")
          # steep:ignore:end
        else
          Rails.root.join('db/functions')
        end
      end
    end
  end
end
