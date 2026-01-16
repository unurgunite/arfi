# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  module MySQLDB
    class << self
      def connect!
        return @available = false if url.nil? || url.empty?

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] MySQL unavailable (#{e.class}: #{e.message}). Skipping mysql specs."
        @available = false
      end

      def url
        ENV.fetch('ARFI_MYSQL_URL', nil)
      end

      def available?
        !!@available
      end

      def reset!
        conn = ActiveRecord::Base.connection

        # drop functions in current db
        routines = conn.exec_query(<<~SQL).rows.flatten
          SELECT ROUTINE_NAME
          FROM information_schema.ROUTINES
          WHERE ROUTINE_TYPE = 'FUNCTION'
            AND ROUTINE_SCHEMA = DATABASE()
        SQL

        routines.each do |fn|
          conn.execute("DROP FUNCTION IF EXISTS `#{fn}`")
        end

        # drop tables
        conn.execute('SET FOREIGN_KEY_CHECKS = 0')
        tables = conn.exec_query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'").rows.map(&:first)
        tables.each do |t|
          conn.execute("DROP TABLE IF EXISTS `#{t}`")
        end
        conn.execute('SET FOREIGN_KEY_CHECKS = 1')
      end
    end
  end
end
