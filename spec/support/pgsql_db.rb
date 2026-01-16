# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  module PgSQLDB
    class << self
      # Probe availability WITHOUT mutating ActiveRecord::Base global connection
      def connect!
        return @available = false if url.nil? || url.empty?

        klass = Class.new(ActiveRecord::Base) { self.abstract_class = true }
        klass.establish_connection(url)
        klass.connection
        klass.connection_pool.disconnect!
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] Postgres unavailable (#{e.class}: #{e.message}). Skipping db specs."
        @available = false
      end

      def available?
        !!@available
      end

      # These methods assume ActiveRecord::Base is already connected to Postgres
      def reset_public_schema!
        ActiveRecord::Base.connection.execute('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;')
      end

      def ensure_connected!
        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      def url
        ENV.fetch('ARFI_DATABASE_URL', nil)
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.respond_to?(:connection_pool)
      rescue StandardError
        # ignore
      end
    end
  end
end
