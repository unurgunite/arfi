# frozen_string_literal: true

require 'thor'
require_relative 'commands/project'

module ARFI
  class CLI < Thor
    desc 'init', 'Initialize the project'
    subcommand 'init', ARFI::Commands::Project
  end
end
