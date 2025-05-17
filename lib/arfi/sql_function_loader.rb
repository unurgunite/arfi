# frozen_string_literal: true

module Arfi
  # +Arfi::SqlFunctionLoader+ is a class which loads user defined SQL functions into database.
  class SqlFunctionLoader
    class << self
      # +Arfi::SqlFunctionLoader.load!+                        -> (nil | void)
      #
      # Loads user defined SQL functions into database.
      #
      # @return [nil] if there is no `db/functions` directory.
      # @return [void] if there is no errors.
      # @raise [Arfi::Errors::AdapterNotSupported] if database adapter is SQLite.
      def load!
        return puts 'No SQL files found. Skipping db population with ARFI' unless sql_files.any?
        raise Arfi::Errors::AdapterNotSupported if conn.adapter_name == 'SQLite'

        if multidb?
          populate_multiple_db
        else
          populate_db
        end
        conn.close
      end

      private

      def multidb?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1
      end

      def populate_multiple_db
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db
        end
      end

      # +Arfi::SqlFunctionLoader#populate_db+                   -> void
      #
      # Loads user defined SQL functions into database.
      #
      # @!visibility private
      # @private
      # @return [void]
      def populate_db
        sql_files.each do |file|
          sql = File.read(file).strip
          conn.execute(sql)
          puts "[ARFI] Loaded: #{File.basename(file)} into #{conn.pool.db_config.env_name} #{conn.pool.db_config.name}"
        end
      end

      # +Arfi::SqlFunctionLoader#sql_files+                     -> Array<String>
      #
      # Helper method to get list of SQL files.
      #
      # @!visibility private
      # @private
      # @return [Array<String>] List of SQL files.
      def sql_files
        if multidb?
          case conn
          when ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
            Dir.glob(Rails.root.join('db', 'functions', 'postgresql').join('*.sql'))
          when ActiveRecord::ConnectionAdapters::Mysql2Adapter
            Dir.glob(Rails.root.join('db', 'functions', 'mysql').join('*.sql'))
          else
            raise Arfi::Errors::AdapterNotSupported
          end
        else
          Dir.glob(Rails.root.join('db', 'functions').join('*.sql'))
        end
      end

      # +Arfi::SqlFunctionLoader#conn+                          -> ActiveRecord::ConnectionAdapters::AbstractAdapter
      #
      # Helper method to get database connection.
      #
      # @!visibility private
      # @private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter] Database connection.
      def conn
        ActiveRecord::Base.lease_connection
      end
    end
  end
end
