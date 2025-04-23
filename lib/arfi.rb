# frozen_string_literal: true

require_relative 'arfi/version'
require 'rails' if defined?(Rails)

module Arfi
  class Error < StandardError; end

  require_relative 'arfi/railtie' if defined?(Rails)
end
