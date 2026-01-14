# frozen_string_literal: true

begin
  require "active_record/connection_adapters/postgresql_adapter"
rescue LoadError
  # no postgres adapter; ok
end

require "arfi/sql_function_loader"

module Arfi
  module PostgreSQL
    module DatabaseStatementsPatch
      ARFI_UNDEFINED_FUNCTION = /
        function\s+([a-zA-Z0-9_."]+)\s*\(.*?\)\s+does\s+not\s+exist
      /ix.freeze

      THREAD_GUARD_KEY = :arfi_reloading_functions

      # Rails 6/7: SELECT often goes through exec_query
      def exec_query(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      # DDL often goes through execute
      def execute(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      # Rails 7+/8 may use raw_execute
      def raw_execute(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      def internal_exec_query(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      private

      def arfi_try_reload_and_retry?(e)
        pg_error = e.cause || e
        return false unless pg_error.class.name == "PG::UndefinedFunction"
        return false if Thread.current[THREAD_GUARD_KEY]

        schema, fn = arfi_extract_function_ident(pg_error.message)
        return false unless arfi_has_function_file_for?(schema, fn)

        Thread.current[THREAD_GUARD_KEY] = true
        begin
          Arfi::SqlFunctionLoader.load!(
            task_name: "arfi:runtime",
            connection: self,                # same connection
            clear_active_connections: false, # runtime retry path
            verbose: false
          )
        ensure
          Thread.current[THREAD_GUARD_KEY] = false
        end

        true
      end

      def arfi_extract_function_ident(message)
        m = message.to_s.match(ARFI_UNDEFINED_FUNCTION)
        return [nil, nil] unless m

        ident = m[1].to_s.delete('"')
        parts = ident.split(".", 2)
        parts.length == 2 ? [parts[0], parts[1]] : [nil, parts[0]]
      end

      def arfi_has_function_file_for?(schema, fn)
        return false if fn.nil? || fn.empty?

        root = Rails.root.join("db", "functions")
        return false unless root.directory?

        candidates = []
        candidates << root.join("public", "#{fn}.sql")
        candidates << root.join("#{fn}.sql") # legacy generic

        pg_root = root.join("postgresql")
        if pg_root.directory?
          candidates << pg_root.join("public", "#{fn}.sql")
          candidates << pg_root.join("#{fn}.sql") # legacy adapter

          if schema && !schema.empty?
            candidates << pg_root.join(schema, "#{fn}.sql")
          else
            candidates.concat Dir.glob(pg_root.join("*", "#{fn}.sql").to_s)
          end
        end

        candidates.any? { |p| File.exist?(p) }
      end
    end
  end
end

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(
    Arfi::PostgreSQL::DatabaseStatementsPatch
  )
end
