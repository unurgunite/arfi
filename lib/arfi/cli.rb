# frozen_string_literal: true

require 'thor'
require_relative 'commands/project'
require_relative 'commands/f_idx'

# steep:ignore:start
module Arfi
  # Top level CLI class
  class CLI < Thor
    desc 'project [COMMAND]', 'Project specific commands.'
    subcommand 'project', Commands::Project

    desc 'f_idx [COMMAND]', 'Command to handle functional indexes.'
    subcommand 'f_idx', Commands::FIdx
  end
end
# steep:ignore:end
