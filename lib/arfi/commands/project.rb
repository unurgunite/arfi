# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'rails'

module Arfi
  module Commands
    class Project < Thor
      ADAPTERS = %i[postgresql mysql].freeze
      ROOT_DIR = 'db/functions'

      # steep:ignore:start
      desc 'create', 'Initialize project by creating db/functions directory (and adapter subdir if provided)'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end

      def create
        raise Arfi::Errors::InvalidSchemaFormat unless ActiveRecord.schema_format == :ruby # steep:ignore NoMethod

        root = Rails.root.join(ROOT_DIR)
        FileUtils.mkdir_p(root)
        puts "Ensured: #{root}"

        return unless options[:adapter] # steep:ignore NoMethod
        # steep:ignore NoMethod
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(options[:adapter].to_sym)

        subdir = root.join(options[:adapter].to_s) # steep:ignore NoMethod
        FileUtils.mkdir_p(subdir)
        puts "Ensured: #{subdir}"
      end
    end
  end
end
