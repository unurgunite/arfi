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

    # Check if a SQL trigger exists in the database, dispatching to the correct adapter method.
    #
    # @param [String] table Table name
    # @param [String] trigger_name Trigger name to check
    # @raise [ActiveRecord::AdapterNotFound] If adapter is not supported
    # @return [Boolean] Whether the trigger exists
    def self.trigger_exists?(table, trigger_name)
      case connection.class.name
      when 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
        pg_trigger_exists?(table, trigger_name)
      when 'ActiveRecord::ConnectionAdapters::Mysql2Adapter', 'ActiveRecord::ConnectionAdapters::TrilogyAdapter'
        mysql_trigger_exists?(table, trigger_name)
      else
        raise ActiveRecord::AdapterNotFound, "adapter #{connection.class.name} is not supported"
      end
    end

    # Check if a trigger exists in PostgreSQL via pg_trigger catalog table.
    #
    # @param [String] table Table name
    # @param [String] trigger_name Trigger name to check
    # @return [Boolean] Whether the trigger exists
    def self.pg_trigger_exists?(table, trigger_name)
      sql = <<~SQL.squish
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE t.tgname = #{connection.quote(trigger_name)}
          AND c.relname = #{connection.quote(table)}
        LIMIT 1
      SQL
      !connection.select_value(sql).nil?
    end

    # Check if a trigger exists in MySQL/MariaDB via information_schema.TRIGGERS.
    #
    # @param [String] table Table name
    # @param [String] trigger_name Trigger name to check
    # @return [Boolean] Whether the trigger exists
    def self.mysql_trigger_exists?(table, trigger_name)
      !connection.select_value(<<~SQL).nil?
        SELECT 1 FROM information_schema.TRIGGERS
        WHERE TRIGGER_SCHEMA = #{connection.quote(connection.current_database)}
          AND EVENT_OBJECT_TABLE = #{connection.quote(table)}
          AND TRIGGER_NAME = #{connection.quote(trigger_name)}
        LIMIT 1;
      SQL
    end
  end
end
