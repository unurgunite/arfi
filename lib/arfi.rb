# frozen_string_literal: true

require_relative 'arfi/version'
require_relative 'arfi/errors'
require 'arfi/extensions/active_record'
require 'rails' if defined?(Rails)

# Top level module
module Arfi
  require_relative 'arfi/railtie' if defined?(Rails)
end
