# frozen_string_literal: true

require 'thor'
require_relative 'commands/init'
require_relative 'commands/functions'

module Arfi
  # Top-level CLI entrypoint for the `arfi` executable.
  #
  # It wires new command groups and keeps backward-compatible aliases:
  # - `arfi init`      (preferred)
  # - `arfi functions` (preferred)
  # - `arfi project`   (alias for init)
  # - `arfi f_idx`     (alias for functions)
  #
  # @api public
  class CLI < Thor
    desc 'init [COMMAND]', 'Initialize ARFI directories (new command). Default: create'
    subcommand 'init', Arfi::Commands::Init

    desc 'project [COMMAND]', 'Alias for `arfi init` (backward compatible).'
    subcommand 'project', Arfi::Commands::Init

    desc 'functions [COMMAND]', 'Manage SQL function files (new command). Default: list'
    subcommand 'functions', Arfi::Commands::Functions

    desc 'f_idx [COMMAND]', 'Alias for `arfi functions` (backward compatible).'
    subcommand 'f_idx', Arfi::Commands::Functions

    desc 'version', 'Print the version'
    # +Arfi::CLI#version+ -> Object
    #
    # Print the ARFI gem version to stdout.
    #
    # @return [void]
    def version
      $stdout.write(Arfi::VERSION, "\n")
    end
  end
end
