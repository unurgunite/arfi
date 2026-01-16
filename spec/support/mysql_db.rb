# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  class MysqlProbeRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  module MySQLDB
    class << self
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

      def available?
        !!@available
      end

      def ensure_connected!
        raise 'ARFI_MYSQL_URL is not set' if url.nil? || url.empty?

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      def url
        ENV.fetch('ARFI_MYSQL_URL', nil)
      end

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

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      rescue StandardError
        nil
      end
    end
  end
end
