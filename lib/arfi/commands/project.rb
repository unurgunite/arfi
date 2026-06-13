# frozen_string_literal: true

require_relative 'init'

module Arfi
  module Commands
    # +Arfi::Commands::Project+ class is used to create `db/functions` directory.
    #
    # Backward-compatible constant for code that references Arfi::Commands::Project.
    # @deprecated
    Project = Init
  end
end
