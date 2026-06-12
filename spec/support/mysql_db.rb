# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  # Named ActiveRecord base class used only for probing MySQL availability without mutating
  # ActiveRecord::Base global connection.
  #
  # @private
  class MysqlProbeRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  # RSpec helper module for MySQL-compatible databases (MySQL/MariaDB) and clients (mysql2/trilogy).
  #
  # This helper is used by specs tagged with `:mysql`.
  #
  # Environment variables:
  # - ARFI_MYSQL_URL (preferred): mysql2://... or trilogy://...
  # - ARFI_TRILOGY_URL (optional legacy): trilogy://...
  #
  # @private
  module MySQLDB
    class << self
      # +ArfiSpec::MySQLDB#connect!+ -> Object
      #
      # Probe MySQL availability without mutating ActiveRecord::Base connection.
      #
      # @private
      # @return [void]
      def connect!
        return @available = false if url.nil? || url.empty?

        MysqlProbeRecord.establish_connection(url)
        MysqlProbeRecord.connection
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] MySQL unavailable (#{e.class}: #{e.message}). Skipping mysql specs."
        @available = false
      ensure
        begin
          MysqlProbeRecord.connection_pool.disconnect!
        rescue StandardError
          nil
        end
      end

      # +ArfiSpec::MySQLDB#available?+ -> Object
      #
      # Whether MySQL specs should run in this environment.
      #
      # @private
      # @return [Boolean]
      def available?
        !!@available
      end

      # +ArfiSpec::MySQLDB#ensure_connected!+ -> Object
      #
      # Establish ActiveRecord::Base connection to the MySQL database for `:mysql` examples.
      #
      # @private
      # @raise [RuntimeError] if ARFI_MYSQL_URL / ARFI_TRILOGY_URL are not set
      # @return [void]
      def ensure_connected!
        raise 'ARFI_MYSQL_URL or ARFI_TRILOGY_URL is not set' if url.nil? || url.empty?

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      # +ArfiSpec::MySQLDB#url+ -> Object
      #
      # Return the configured MySQL connection URL.
      #
      # Prefers ARFI_MYSQL_URL, falls back to ARFI_TRILOGY_URL if present.
      #
      # @private
      # @return [String, nil]
      def url
        mysql = ENV.fetch('ARFI_MYSQL_URL', nil)
        tri = ENV.fetch('ARFI_TRILOGY_URL', nil)

        raise 'Set only one of ARFI_MYSQL_URL or ARFI_TRILOGY_URL' if mysql && !mysql.empty? && tri && !tri.empty?

        return mysql if mysql && !mysql.empty?
        return tri if tri && !tri.empty?

        nil
      end

      # +ArfiSpec::MySQLDB#reset!+ -> Object
      #
      # Reset the current MySQL database schema for test isolation.
      #
      # Drops:
      # - all functions in the current database
      # - all tables in the current database
      #
      # @private
      # @return [void]
      def reset!
        conn = ActiveRecord::Base.connection

        routines = conn.exec_query(<<~SQL).rows.flatten
          SELECT ROUTINE_NAME
          FROM information_schema.ROUTINES
          WHERE ROUTINE_TYPE = 'FUNCTION'
            AND ROUTINE_SCHEMA = DATABASE()
        SQL

        routines.each { |fn| conn.execute("DROP FUNCTION IF EXISTS `#{fn}`") }

        conn.execute('SET FOREIGN_KEY_CHECKS = 0')
        tables = conn.exec_query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'").rows.map(&:first)
        tables.each { |t| conn.execute("DROP TABLE IF EXISTS `#{t}`") }
        conn.execute('SET FOREIGN_KEY_CHECKS = 1')
      end

      # +ArfiSpec::MySQLDB#disconnect!+ -> Object
      #
      # Disconnect ActiveRecord::Base from MySQL to avoid leaking connections between examples.
      #
      # @private
      # @return [void]
      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      rescue StandardError
        nil
      end
    end
  end
end
