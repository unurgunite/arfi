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
    def self.function_exists?(function_name) # rubocop:disable Metrics/MethodLength
      case connection
      when ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
        sql = "SELECT 1 FROM pg_proc WHERE proname = #{connection.quote(function_name)} LIMIT 1"
        connection.select_value(sql).present?
      when ActiveRecord::ConnectionAdapters::Mysql2Adapter
        schema = connection.quote(connection.current_database)
        name   = connection.quote(function_name)

        sql = <<~SQL
          SELECT 1
          FROM information_schema.ROUTINES
          WHERE ROUTINE_TYPE = 'FUNCTION'
            AND ROUTINE_SCHEMA = #{schema}
            AND ROUTINE_NAME = #{name}
          LIMIT 1;
        SQL

        connection.select_value(sql).present?
      else
        raise ActiveRecord::AdapterNotFound, "adapter #{connection.class.name} is not supported"
      end
    end
  end
end
