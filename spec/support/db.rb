# frozen_string_literal: true

require 'active_record'

module ArfiSpec
  module DB
    class << self
      def connect!
        url = ENV.fetch('ARFI_DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/arfi_test')
        ActiveRecord::Base.establish_connection(url)
        ActiveRecord::Base.connection
      end

      def reset_public_schema!
        # Fast reset; avoids create/drop database (needs privileges to drop schema)
        conn.execute('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;')
      end

      def conn
        ActiveRecord::Base.connection
      end
    end
  end
end
