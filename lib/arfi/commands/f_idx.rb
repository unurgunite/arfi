# frozen_string_literal: true

require_relative 'functions'

module Arfi
  module Commands
    # +Arfi::Commands::FIdx+ module contains commands for manipulating functional index in Rails project.
    #
    # Backward-compatible constant for code that references Arfi::Commands::FIdx.
    # @deprecated
    FIdx = Functions
  end
end
