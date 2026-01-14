# frozen_string_literal: true

# Important:
# Requiring active_record/.../postgresql/database_statements directly can load code that
# references PG before the pg gem is loaded in test/minimal environments.
#
# Requiring the adapter is the safer entrypoint; it normally pulls in pg + dependencies.
begin
  require "active_record/connection_adapters/postgresql_adapter"
rescue LoadError
  # App doesn't have the PostgreSQL adapter / pg gem. That's OK.
end

require "arfi/sql_function_loader"

module Arfi
  module PostgreSQL
    module DatabaseStatementsPatch
      ARFI_UNDEFINED_FUNCTION = /
        function\s+([a-zA-Z0-9_."]+)\s*\(.*?\)\s+does\s+not\s+exist
      /ix.freeze

      THREAD_GUARD_KEY = :arfi_reloading_functions

      def raw_execute(*args, **kwargs)
        super
      rescue StandardError => e
        pg_error = e.cause || e
        raise unless pg_error.class.name == "PG::UndefinedFunction"

        raise if Thread.current[THREAD_GUARD_KEY]

        schema, fn = arfi_extract_function_ident(pg_error.message)
        raise unless arfi_has_function_file_for?(schema, fn)

        Thread.current[THREAD_GUARD_KEY] = true
        begin
          Arfi::SqlFunctionLoader.load!(
            task_name: "arfi:runtime",
            connection: self,
            clear_active_connections: false,
            verbose: false
          )
          retry
        ensure
          Thread.current[THREAD_GUARD_KEY] = false
        end
      end

      private

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
        candidates << root.join("#{fn}.sql") # legacy

        pg_root = root.join("postgresql")
        if pg_root.directory?
          candidates << pg_root.join("public", "#{fn}.sql")
          candidates << pg_root.join("#{fn}.sql") # legacy

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

# Only prepend if the target module is actually loaded.
if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements)
  ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.prepend(
    Arfi::PostgreSQL::DatabaseStatementsPatch
  )
end
