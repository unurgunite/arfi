# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    # Initializes ARFI directory structure inside a Rails project.
    #
    # Creates/ensures:
    # - db/functions/public
    # - db/functions/<adapter>/public (when adapter provided)
    #
    # @api public
    class Init < Thor
      ADAPTERS = %i[postgresql mysql].freeze
      ROOT_DIR = 'db/functions'
      DEFAULT_SCHEMA = 'public'

      default_task :create

      # UX aliases
      map %w[setup] => :create

      desc 'create', 'Initialize project by creating db/functions structure (explicit public schema dirs)'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'

      # +Arfi::Commands::Init#create+ -> Object
      #
      # Create (or ensure) ARFI directories exist.
      #
      # @raise [Arfi::Errors::InvalidSchemaFormat]
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def create
        validate_schema_format!
        create_base_dirs
        create_adapter_dirs if options[:adapter] # steep:ignore NoMethod
      end

      private

      # +Arfi::Commands::Init#validate_schema_format!+ -> Object
      #
      # Validate that Rails schema format is ruby (:ruby / schema.rb).
      #
      # @private
      # @raise [Arfi::Errors::InvalidSchemaFormat]
      # @return [void]
      def validate_schema_format!
        fmt =
          if defined?(Rails) && Rails.application
            Rails.application.config.active_record.schema_format
          elsif defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:schema_format)
            ActiveRecord::Base.schema_format
          end

        raise Arfi::Errors::InvalidSchemaFormat unless fmt == :ruby
      end

      def create_base_dirs
        root = Rails.root.join(ROOT_DIR)
        FileUtils.mkdir_p(root)
        puts "Ensured: #{root}"
        FileUtils.mkdir_p(root.join(DEFAULT_SCHEMA))
        puts "Ensured: #{root.join(DEFAULT_SCHEMA)}"
      end

      def create_adapter_dirs
        adapter = options[:adapter].to_s # steep:ignore NoMethod
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(adapter.to_sym)

        root = Rails.root.join(ROOT_DIR)
        adapter_root = root.join(adapter)
        FileUtils.mkdir_p(adapter_root)
        puts "Ensured: #{adapter_root}"
        FileUtils.mkdir_p(adapter_root.join(DEFAULT_SCHEMA))
        puts "Ensured: #{adapter_root.join(DEFAULT_SCHEMA)}"
      end
    end
  end
end
