# frozen_string_literal: true

require 'active_record'

module ActiveRecord
  class Base # :nodoc:
    # +ActiveRecord::Base.function_exists?+               -> bool
    #
    # This method checks if a custom SQL function exists in the database.
    #
    # @example
    #   ActiveRecord::Base.function_exists?('my_function') #=> true
    #   ActiveRecord::Base.function_exists?('my_function123') #=> false
    # @param [String] function_name The name of the function to check.
    # @return [Boolean] Returns true if the function exists, false otherwise.
    def self.function_exists?(function_name)
      connection.execute("SELECT * FROM pg_proc WHERE proname = '#{function_name}'").any?
    end
  end
end
