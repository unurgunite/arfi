# frozen_string_literal: true

require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # @todo: Maybe it should be removed later...
      def exec_no_cache(sql, name, binds, async:, allow_retry:, materialize_transactions:)
        mark_transaction_written_if_write(sql)

        # make sure we carry over any changes to ActiveRecord.default_timezone that have been
        # made since we established the connection
        update_typemap_for_default_timezone

        type_casted_binds = type_casted_binds(binds)
        log(sql, name, binds, type_casted_binds, async: async) do |notification_payload|
          with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            result = conn.exec_params(sql, type_casted_binds)
            verified!
            notification_payload[:row_count] = result.count
            result
          end
        end
      end
    end
  end
end
