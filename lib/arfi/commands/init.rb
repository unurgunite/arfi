# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    class Init < Thor
      ADAPTERS = %i[postgresql mysql].freeze
      ROOT_DIR = 'db/functions'
      DEFAULT_SCHEMA = 'public'

      default_task :create

      # UX aliases
      map %w[setup] => :create

      # steep:ignore:start
      desc 'create', 'Initialize project by creating db/functions structure (explicit public schema dirs)'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end
      def create
        validate_schema_format!

        root = Rails.root.join(ROOT_DIR)
        FileUtils.mkdir_p(root)
        puts "Ensured: #{root}"

        FileUtils.mkdir_p(root.join(DEFAULT_SCHEMA))
        puts "Ensured: #{root.join(DEFAULT_SCHEMA)}"

        return unless options[:adapter] # steep:ignore NoMethod

        adapter = options[:adapter].to_s # steep:ignore NoMethod
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(adapter.to_sym)

        adapter_root = root.join(adapter)
        FileUtils.mkdir_p(adapter_root)
        puts "Ensured: #{adapter_root}"

        FileUtils.mkdir_p(adapter_root.join(DEFAULT_SCHEMA))
        puts "Ensured: #{adapter_root.join(DEFAULT_SCHEMA)}"
      end

      private

      def validate_schema_format!
        fmt =
          if defined?(Rails) && Rails.application
            Rails.application.config.active_record.schema_format
          elsif defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:schema_format)
            ActiveRecord::Base.schema_format
          end

        raise Arfi::Errors::InvalidSchemaFormat unless fmt == :ruby
      end
    end
  end
end
