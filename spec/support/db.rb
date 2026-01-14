# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  module DB
    class << self
      def connect!
        url = ENV.fetch('ARFI_DATABASE_URL', nil)
        unless url && !url.empty?
          @available = false
          return
        end

        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection # force connection now
        @available = true
      rescue StandardError => e
        warn "[ARFI SPEC] DB unavailable (#{e.class}: #{e.message}). Skipping :db specs."
        @available = false
      end

      def reset_public_schema!
        raise 'DB not available' unless available?

        conn.execute('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;')
      end

      def available?
        !!@available
      end

      def conn
        ActiveRecord::Base.connection
      end
    end
  end
end
