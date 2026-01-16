# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  # Named class to avoid: "Anonymous class is not allowed."
  class PgsqlProbeRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  module PgSQLDB
    class << self
      # Probe availability WITHOUT mutating ActiveRecord::Base connection
      def connect!
        return @available = false if url.nil? || url.empty?

        PgsqlProbeRecord.establish_connection(url)
        PgsqlProbeRecord.connection
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] Postgres unavailable (#{e.class}: #{e.message}). Skipping pgsql specs."
        @available = false
      ensure
        begin
          PgsqlProbeRecord.connection_pool.disconnect!
        rescue StandardError
          nil
        end
      end

      def available?
        !!@available
      end

      # Used in :pgsql hooks — this DOES mutate ActiveRecord::Base (intentionally)
      def ensure_connected!
        raise 'ARFI_POSTGRES_URL is not set' if url.nil? || url.empty?

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      def url
        ENV.fetch('ARFI_POSTGRES_URL', nil)
      end

      def reset_public_schema!
        conn = ActiveRecord::Base.connection
        conn.execute('DROP SCHEMA IF EXISTS public CASCADE')
        conn.execute('CREATE SCHEMA public')
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      rescue StandardError
        nil
      end
    end
  end
end
