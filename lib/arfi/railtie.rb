# frozen_string_literal: true

require 'arfi'
require 'rails'

module Arfi
  class Railtie < ::Rails::Railtie # :nodoc:
    railtie_name :arfi

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
    end
  end
end
