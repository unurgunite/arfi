# frozen_string_literal: true

require 'active_record'

module ActiveRecord
  class Base # :nodoc:
    # Check if a SQL function exists in the database, dispatching to the correct adapter method.
    #
    # @param [String] function_name Function name to check
    # @raise [ActiveRecord::AdapterNotFound] If adapter is not supported
    # @return [Boolean] Whether the function exists
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

    # Check if a function exists in PostgreSQL via pg_proc catalog table.
    #
    # @param [String] function_name Function name to check
    # @return [Boolean] Whether the function exists
    def self.pg_function_exists?(function_name)
      sql = "SELECT 1 FROM pg_proc WHERE proname = #{connection.quote(function_name)} LIMIT 1"
      !connection.select_value(sql).nil?
    end

    # Check if a function exists in MySQL/MariaDB via information_schema.ROUTINES.
    #
    # @param [String] function_name Function name to check
    # @return [Boolean] Whether the function exists
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
