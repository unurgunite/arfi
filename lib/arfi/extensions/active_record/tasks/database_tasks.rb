# frozen_string_literal: true

module ActiveRecord
  module Tasks
    # @!visibility private
    # Under construction.
    module DatabaseTasks
      # class << self
      #   alias original_load_schema load_schema
      #
      #   def load_schema(*args)
      #     Arfi::SqlFunctionLoader.load!
      #     original_load_schema(*args)
      #   end
      #
      #   alias original_load_schema_current load_schema_current
      #
      #   def load_schema_current(*args)
      #     Arfi::SqlFunctionLoader.load!
      #     original_load_schema_current(*args)
      #   end
      #
      #   alias original_dump_schema dump_schema
      #
      #   def dump_schema(*args)
      #     Arfi::SqlFunctionLoader.load!
      #     original_dump_schema(*args)
      #   end
      # end
    end
  end
end
