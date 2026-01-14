# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require_relative 'spec_helper'

require 'logger'
require 'rails'
require 'active_record/railtie'

# Boot a minimal Rails app in-process (no generated rails app needed)
module ArfiSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = 'test'
    config.logger = Logger.new($stdout)

    # Important for your Thor commands (validate_schema_format!)
    config.active_record.schema_format = :ruby
  end
end

# Avoid double-initialization if rails_helper is required multiple times
ArfiSpec::Application.initialize! unless Rails.application

require 'arfi'

# Load spec support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

# DB availability + tagging
ArfiSpec::DB.connect!

RSpec.configure do |config|
  # If DB isn't available, skip :db specs but still run everything else
  config.filter_run_excluding db: true unless ArfiSpec::DB.available?

  # Only reset schema for DB specs
  config.before(:each, :db) do
    ArfiSpec::DB.reset_public_schema!
  end
end
