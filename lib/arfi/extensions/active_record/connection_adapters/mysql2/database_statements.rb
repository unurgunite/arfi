# frozen_string_literal: true

require 'active_record/connection_adapters/mysql2/database_statements'

module ActiveRecord
  module ConnectionAdapters
    module Mysql2
      module DatabaseStatements
        # @todo Maybe it should be removed later...
        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          log(sql, name, async: async) do |notification_payload|
            with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
              sync_timezone_changes(conn)
              result = conn.query(sql)
              conn.abandon_results!
              verified!
              handle_warnings(sql)
              notification_payload[:row_count] = result&.size || 0
              result
            end
          end
        end
      end
    end
  end
end
