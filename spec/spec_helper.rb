# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require 'bundler/setup'
require 'rspec'
require 'logger'
require 'tmpdir'
require 'pathname'

require 'rails'
require 'active_record/railtie'

# Boot a minimal Rails app in-process (no generated rails app needed)
module ArfiSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = 'test'
    config.logger = Logger.new($stdout)
    config.active_record.schema_format = :ruby
  end
end

ArfiSpec::Application.initialize!

require 'arfi' # loads your gem code

# Helpers
require_relative 'support/db'
require_relative 'support/tmp_root'

RSpec.configure do |config|
  config.order = :random
  config.example_status_persistence_file_path = '.rspec_status'

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    ArfiSpec::DB.connect!
  end

  config.before do
    ArfiSpec::DB.reset_public_schema!
  end
end
