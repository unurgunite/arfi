# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require_relative 'spec_helper'

require 'logger'
require 'rails'
require 'active_record/railtie'

module ArfiSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = 'test'
    config.logger = Logger.new($stdout)
    config.active_record.schema_format = :ruby
  end
end

# Avoid double-initialization if rails_helper is required multiple times
ArfiSpec::Application.initialize! unless Rails.application

require 'arfi'

Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }

# Probe DB availability (does NOT mutate ActiveRecord::Base connection anymore)
ArfiSpec::PgSQLDB.connect!
ArfiSpec::MySQLDB.connect! if defined?(ArfiSpec::MySQLDB)

RSpec.configure do |config|
  config.filter_run_excluding pgsql: true unless ArfiSpec::PgSQLDB.available?
  config.filter_run_excluding mysql: true unless ArfiSpec::MySQLDB.available?

  config.before(:each, :pgsql) do
    ArfiSpec::PgSQLDB.ensure_connected!
    ArfiSpec::PgSQLDB.reset_public_schema!
  end

  config.after(:each, :pgsql) do
    ArfiSpec::PgSQLDB.disconnect!
  end

  config.before(:each, :mysql) do
    ArfiSpec::MySQLDB.ensure_connected!
    ArfiSpec::MySQLDB.reset!
  end

  config.after(:each, :mysql) do
    ArfiSpec::MySQLDB.disconnect!
  end
end
