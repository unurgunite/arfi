# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  module MySQLDB
    class << self
      # Probe availability WITHOUT mutating ActiveRecord::Base
      def connect!
        return @available = false if url.nil? || url.empty?

        klass = Class.new(ActiveRecord::Base) { self.abstract_class = true }
        klass.establish_connection(url)
        klass.connection
        klass.connection_pool.disconnect!
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] MySQL unavailable (#{e.class}: #{e.message}). Skipping mysql specs."
        @available = false
      end

      def available?
        !!@available
      end

      # Assume ActiveRecord::Base is already connected to MySQL
      def reset!
        conn = ActiveRecord::Base.connection

        # Drop functions in current database
        routines = conn.exec_query(<<~SQL).rows.flatten
          SELECT ROUTINE_NAME
          FROM information_schema.ROUTINES
          WHERE ROUTINE_TYPE = 'FUNCTION'
            AND ROUTINE_SCHEMA = DATABASE()
        SQL

        routines.each do |fn|
          conn.execute("DROP FUNCTION IF EXISTS `#{fn}`")
        end

        # Drop tables
        conn.execute('SET FOREIGN_KEY_CHECKS = 0')
        tables = conn.exec_query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'").rows.map(&:first)
        tables.each { |t| conn.execute("DROP TABLE IF EXISTS `#{t}`") }
        conn.execute('SET FOREIGN_KEY_CHECKS = 1')
      end

      def ensure_connected!
        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      def url
        ENV.fetch('ARFI_MYSQL_URL', nil)
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.respond_to?(:connection_pool)
      rescue StandardError
        # ignore
      end
    end
  end
end
