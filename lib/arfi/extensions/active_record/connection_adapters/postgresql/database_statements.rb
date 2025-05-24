# frozen_string_literal: true

require 'active_record/connection_adapters/postgresql/database_statements'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module DatabaseStatements
        # This patch is used for db:prepare task.
        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          log(sql, name, async: async) do |notification_payload|
            with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
              result = conn.async_exec(sql)
              verified!
              handle_warnings(result)
              notification_payload[:row_count] = result.count
              result
            rescue => e
              if e.message.match?(/ERROR:\s{2}function (\S+\(\w+\)) does not exist/)
                function_name = e.message.match(/ERROR:\s{2}function (\S+\(\w+\)) does not exist/)[1][/^[^(]*/]
                if (function_file = Dir.glob(Rails.root.join('db', 'functions', "#{function_name}_v*.sql").to_s).first)
                  conn.async_exec(File.read(function_file).chop)
                  retry
                end
              end
            end
          end
        end
      end
    end
  end
end
