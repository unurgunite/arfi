# frozen_string_literal: true

require 'thor'
require_relative 'commands/project'
require_relative 'commands/f_idx'

module Arfi
  class CLI < Thor
    desc 'init:project', 'Initialize the project'
    subcommand 'init:project', Commands::Project

    desc 'init:f_idx', 'Initialize the functional index'
    subcommand 'init:f_idx', Commands::FIdx
  end
end
