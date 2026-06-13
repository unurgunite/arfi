# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  # Named ActiveRecord base class used only for probing PostgreSQL availability without mutating
  # ActiveRecord::Base global connection.
  #
  # @private
  class PgsqlProbeRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  # RSpec helper module for PostgreSQL integration specs.
  #
  # This helper is used by specs tagged with `:pgsql`.
  #
  # Environment variables:
  # - ARFI_POSTGRES_URL: postgresql://...
  #
  # @private
  module PgSQLDB
    class << self
      # +ArfiSpec::PgSQLDB#connect!+ -> Object
      #
      # Probe PostgreSQL availability without mutating ActiveRecord::Base connection.
      #
      # @private
      # @return [void]
      def connect!
        return @available = false if url.nil? || url.empty?

        PgsqlProbeRecord.establish_connection(url)
        PgsqlProbeRecord.connection
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] Postgres unavailable (#{e.class}: #{e.message}). Skipping pgsql specs."
        @available = false
      ensure
        safe_disconnect_probe!
      end

      # +ArfiSpec::PgSQLDB#available?+ -> Object
      #
      # Whether PostgreSQL specs should run in this environment.
      #
      # @private
      # @return [Boolean]
      def available?
        !!@available
      end

      # +ArfiSpec::PgSQLDB#ensure_connected!+ -> Object
      #
      # Establish ActiveRecord::Base connection to PostgreSQL for `:pgsql` examples.
      #
      # @private
      # @raise [RuntimeError] if ARFI_POSTGRES_URL is not set
      # @return [void]
      def ensure_connected!
        raise 'ARFI_POSTGRES_URL is not set' if url.nil? || url.empty?

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      # +ArfiSpec::PgSQLDB#url+ -> Object
      #
      # Return the configured PostgreSQL connection URL.
      #
      # @private
      # @return [String, nil]
      def url
        ENV.fetch('ARFI_POSTGRES_URL', nil)
      end

      # +ArfiSpec::PgSQLDB#reset_public_schema!+ -> Object
      #
      # Reset PostgreSQL `public` schema for test isolation.
      #
      # @private
      # @return [void]
      def reset_public_schema!
        conn = ActiveRecord::Base.connection
        conn.execute('DROP SCHEMA IF EXISTS public CASCADE')
        conn.execute('CREATE SCHEMA public')
      end

      def safe_disconnect_probe!
        PgsqlProbeRecord.connection_pool.disconnect!
      rescue StandardError
        nil
      end

      # +ArfiSpec::PgSQLDB#disconnect!+ -> Object
      #
      # Disconnect ActiveRecord::Base from PostgreSQL to avoid leaking connections between examples.
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
