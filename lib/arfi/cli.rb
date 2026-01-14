# frozen_string_literal: true

require 'thor'
require_relative 'commands/init'
require_relative 'commands/functions'

module Arfi
  class CLI < Thor
    desc 'init [COMMAND]', 'Initialize ARFI directories (new command). Default: create'
    subcommand 'init', Arfi::Commands::Init

    # Old name alias -> new command
    desc 'project [COMMAND]', 'Alias for `arfi init` (backward compatible).'
    subcommand 'project', Arfi::Commands::Init

    desc 'functions [COMMAND]', 'Manage SQL function files (new command). Default: list'
    subcommand 'functions', Arfi::Commands::Functions

    # Old name alias -> new command
    desc 'f_idx [COMMAND]', 'Alias for `arfi functions` (backward compatible).'
    subcommand 'f_idx', Arfi::Commands::Functions

    desc 'version', 'Print the version'
    def version
      $stdout.write(Arfi::VERSION, "\n")
    end
  end
end
