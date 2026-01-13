# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/database_statements"

module Arfi
  module PostgreSQL
    module DatabaseStatementsPatch
      # Examples:
      #   ERROR:  function my_fn(text) does not exist
      #   ERROR:  function public.my_fn(integer, text) does not exist
      #   ERROR:  function "public"."MyFn"(text) does not exist
      ARFI_UNDEFINED_FUNCTION = /
        function\s+([a-zA-Z0-9_."]+)\s*\(.*?\)\s+does\s+not\s+exist
      /ix.freeze

      THREAD_GUARD_KEY = :arfi_reloading_functions

      # Keep signature flexible across Rails versions
      def raw_execute(*args, **kwargs)
        super
      rescue ::PG::UndefinedFunction => e
        raise if Thread.current[THREAD_GUARD_KEY]

        fn = arfi_extract_function_name(e.message)

        # If we can't map it to one of our managed files, don't try to be clever.
        # (This avoids reloading for random missing builtins / extensions.)
        raise unless arfi_has_function_file_for?(fn)

        Thread.current[THREAD_GUARD_KEY] = true
        begin
          with_raw_connection(**arfi_with_raw_connection_kwargs(kwargs)) do |conn|
            # “Current DB state” strategy: just reload all known functions once.
            arfi_reload_all_functions!(conn)
          end

          retry
        ensure
          Thread.current[THREAD_GUARD_KEY] = false
        end
      end

      private

      def arfi_with_raw_connection_kwargs(kwargs)
        # Rails versions differ; only pass what exists to avoid unknown keyword errors.
        opts = {}
        opts[:allow_retry] = kwargs[:allow_retry] if kwargs.key?(:allow_retry)
        opts[:materialize_transactions] = kwargs[:materialize_transactions] if kwargs.key?(:materialize_transactions)
        opts
      end

      def arfi_extract_function_name(message)
        m = message.match(ARFI_UNDEFINED_FUNCTION)
        return nil unless m

        # Strip schema + quotes:
        #   public.my_fn => my_fn
        #   "public"."my_fn" => my_fn
        m[1].to_s.split(".").last.delete('"')
      end

      def arfi_functions_root
        Rails.root.join("db", "functions")
      end

      def arfi_generic_dir
        arfi_functions_root
      end

      def arfi_adapter_dir
        arfi_functions_root.join("postgresql")
      end

      # Adapter dir should override generic for same function name.
      def arfi_function_files_by_name
        files = {}

        # Load generic first...
        [arfi_generic_dir, arfi_adapter_dir].each do |dir|
          next unless dir.directory?

          Dir.glob(dir.join("*.sql").to_s).sort.each do |path|
            base = File.basename(path, ".sql")

            # Optional: ignore helper files like README.sql or _shared.sql
            next if base.start_with?("_")

            files[base] = path
          end
        end

        files
      end

      def arfi_all_function_files
        # Deterministic order
        arfi_function_files_by_name.values.sort_by { |p| File.basename(p) }
      end

      def arfi_find_function_file(function_name)
        return nil if function_name.nil? || function_name.empty?

        files = arfi_function_files_by_name
        files[function_name]
      end

      def arfi_has_function_file_for?(function_name)
        !!arfi_find_function_file(function_name)
      end

      def arfi_reload_all_functions!(conn)
        arfi_all_function_files.each do |file|
          sql = File.read(file)
          next if sql.strip.empty?

          conn.async_exec(sql)
        end
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.prepend(
  Arfi::PostgreSQL::DatabaseStatementsPatch
)
