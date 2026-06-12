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
    # @raise [ActiveRecord::AdapterNotFound]
    # @return [Boolean] Returns true if the function exists, false otherwise.
    def self.function_exists?(function_name)
      case connection.class.name
      when 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
        pg_function_exists?(function_name)
      when 'ActiveRecord::ConnectionAdapters::Mysql2Adapter', 'ActiveRecord::ConnectionAdapters::TrilogyAdapter'
        mysql_function_exists?(function_name)
      else
        raise ActiveRecord::AdapterNotFound, "adapter #{connection.class.name} is not supported"
      end
    end

    def self.pg_function_exists?(function_name)
      sql = "SELECT 1 FROM pg_proc WHERE proname = #{connection.quote(function_name)} LIMIT 1"
      !connection.select_value(sql).nil?
    end

    def self.mysql_function_exists?(function_name)
      !connection.select_value(<<~SQL).nil?
        SELECT 1 FROM information_schema.ROUTINES
        WHERE ROUTINE_TYPE = 'FUNCTION'
          AND ROUTINE_SCHEMA = #{connection.quote(connection.current_database)}
          AND ROUTINE_NAME = #{connection.quote(function_name)}
        LIMIT 1;
      SQL
    end
  end
end
