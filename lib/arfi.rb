# frozen_string_literal: true

require_relative 'arfi/version'
require_relative 'arfi/errors'
require_relative 'arfi/cli'
require_relative 'arfi/commands/f_idx'
require 'arfi/extensions/extensions'
require 'rails' if defined?(Rails)

# Top level module
module Arfi
  require_relative 'arfi/railtie' if defined?(Rails)
end
