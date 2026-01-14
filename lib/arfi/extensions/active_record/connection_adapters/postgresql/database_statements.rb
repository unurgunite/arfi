# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/database_statements"
require "arfi/sql_function_loader"

module Arfi
  module PostgreSQL
    module DatabaseStatementsPatch
      # Matches typical PG undefined function errors, including optional schema + quotes:
      #
      #   ERROR:  function my_fn(text) does not exist
      #   ERROR:  function public.my_fn(integer, text) does not exist
      #   ERROR:  function "public"."MyFn"(text) does not exist
      #
      # Captures: my_fn OR public.my_fn OR "public"."MyFn"
      ARFI_UNDEFINED_FUNCTION = /
        function\s+([a-zA-Z0-9_."]+)\s*\(.*?\)\s+does\s+not\s+exist
      /ix.freeze

      THREAD_GUARD_KEY = :arfi_reloading_functions

      # Keep signature flexible across Rails versions
      def raw_execute(*args, **kwargs)
        super
      rescue ::PG::UndefinedFunction => e
        # Avoid infinite loops if reload doesn't fix it (or reload itself errors).
        raise if Thread.current[THREAD_GUARD_KEY]

        schema, fn = arfi_extract_function_ident(e.message)

        # Only attempt recovery if the function appears to be managed by ARFI (file exists).
        raise unless arfi_has_function_file_for?(schema, fn)

        Thread.current[THREAD_GUARD_KEY] = true
        begin
          # Reload function definitions (task_name forces "single target DB" behavior in some multi-db setups).
          # clear_active_connections MUST be false here, because we're inside a query retry path.
          Arfi::SqlFunctionLoader.load!(
            task_name: "arfi:runtime",
            clear_active_connections: false,
            verbose: false
          )

          retry
        ensure
          Thread.current[THREAD_GUARD_KEY] = false
        end
      end

      private

      # Returns [schema, function] where schema may be nil if not present in the error.
      def arfi_extract_function_ident(message)
        m = message.match(ARFI_UNDEFINED_FUNCTION)
        return [nil, nil] unless m

        ident = m[1].to_s

        # Strip quotes, but preserve case inside quotes (e.g. "MyFn" => MyFn).
        ident = ident.delete('"')

        parts = ident.split(".", 2)
        parts.length == 2 ? [parts[0], parts[1]] : [nil, parts[0]]
      end

      # Option B filesystem contract (explicit public):
      #   db/functions/public/<fn>.sql
      #   db/functions/postgresql/public/<fn>.sql
      #   db/functions/postgresql/<schema>/<fn>.sql
      #
      # Legacy aliases (still supported):
      #   db/functions/<fn>.sql
      #   db/functions/postgresql/<fn>.sql
      #
      # If schema is absent in the error (common for unqualified calls), we treat it as "unknown"
      # and consider it managed if the function exists in public OR in any schema dir.
      def arfi_has_function_file_for?(schema, fn)
        return false if fn.nil? || fn.empty?

        root = Rails.root.join("db", "functions")
        return false unless root.directory?

        candidates = []

        # Explicit generic public
        candidates << root.join("public", "#{fn}.sql")

        # Legacy generic public alias
        candidates << root.join("#{fn}.sql")

        pg_root = root.join("postgresql")
        if pg_root.directory?
          # Explicit adapter public
          candidates << pg_root.join("public", "#{fn}.sql")

          # Legacy adapter public alias
          candidates << pg_root.join("#{fn}.sql")

          if schema && !schema.empty?
            # Schema-qualified call => check that schema dir too
            candidates << pg_root.join(schema, "#{fn}.sql")
          else
            # Unqualified call => schema unknown; if fn exists in ANY schema dir, treat as managed.
            candidates.concat Dir.glob(pg_root.join("*", "#{fn}.sql").to_s)
          end
        end

        candidates.any? { |p| File.exist?(p) }
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.prepend(
  Arfi::PostgreSQL::DatabaseStatementsPatch
)