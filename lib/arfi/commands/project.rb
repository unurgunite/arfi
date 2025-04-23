# frozen_string_literal: true

require 'thor'
require 'fileutils'

module Arfi
  module Commands
    class Project < Thor
      desc 'create', 'Initialize project by creating db/functions directory'

      def create
        unless defined?(Rails) && Rails.respond_to?(:root)
          puts 'Error: Rails is not loaded. Are you running this inside a Rails project?'
          exit(1)
        end

        functions_dir = Rails.root.join('db/functions')
        FileUtils.mkdir_p(functions_dir)
        puts "Created: #{functions_dir}"
      end
    end
  end
end
