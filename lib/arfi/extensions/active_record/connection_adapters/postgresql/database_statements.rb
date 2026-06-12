# frozen_string_literal: true

begin
  require "active_record/connection_adapters/postgresql_adapter"
rescue LoadError
  # no postgres adapter; ok
end

require "arfi/sql_function_loader"

module Arfi
  module PostgreSQL
    # ActiveRecord adapter patch for PostgreSQL.
    #
    # When a query fails with `PG::UndefinedFunction`, ARFI checks whether the missing function
    # is managed by ARFI (file exists under db/functions). If yes, ARFI loads function SQL files
    # via {Arfi::SqlFunctionLoader.load!} and retries the failed query once.
    #
    # @api public
    module DatabaseStatementsPatch
      ARFI_UNDEFINED_FUNCTION = /
        function\s+([a-zA-Z0-9_."]+)\s*\(.*?\)\s+does\s+not\s+exist
      /ix.freeze

      THREAD_GUARD_KEY = :arfi_reloading_functions

      # Execute a SQL query, reloading missing ARFI-managed functions and retrying on PG::UndefinedFunction.
      #
      # @param [Array<Object>] args Positional arguments forwarded to the original exec_query
      # @param [Object] kwargs Keyword arguments forwarded to the original exec_query
      # @raise [StandardError] If the error is not recoverable
      # @return [Object] Query result
      # @return [Object] if StandardError (retry successful)
      def exec_query(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      # Execute raw SQL, reloading missing ARFI-managed functions and retrying on PG::UndefinedFunction.
      #
      # @param [Array<Object>] args Positional arguments forwarded to the original execute
      # @param [Object] kwargs Keyword arguments forwarded to the original execute
      # @raise [StandardError] If the error is not recoverable
      # @return [Object] Execution result
      # @return [Object] if StandardError (retry successful)
      def execute(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      # Execute a raw SQL statement, reloading missing ARFI-managed functions and retrying on PG::UndefinedFunction.
      #
      # @param [Array<Object>] args Positional arguments forwarded to the original raw_execute
      # @param [Object] kwargs Keyword arguments forwarded to the original raw_execute
      # @raise [StandardError] If the error is not recoverable
      # @return [Object] Execution result
      # @return [Object] if StandardError (retry successful)
      def raw_execute(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      # Execute an internal query, reloading missing ARFI-managed functions and retrying on PG::UndefinedFunction.
      #
      # @param [Array<Object>] args Positional arguments forwarded to the original internal_exec_query
      # @param [Object] kwargs Keyword arguments forwarded to the original internal_exec_query
      # @raise [StandardError] If the error is not recoverable
      # @return [Object] Query result
      # @return [Object] if StandardError (retry successful)
      def internal_exec_query(*args, **kwargs)
        super
      rescue StandardError => e
        raise unless arfi_try_reload_and_retry?(e)
        retry
      end

      private

      # Check if the error is caused by a missing ARFI-managed function and attempt to reload it.
      #
      # Uses a thread guard to prevent recursive retries.
      #
      # @private
      # @param [Object] e The raised exception (StandardError with possible PG::UndefinedFunction cause)
      # @return [Boolean] Whether the error was handled (reload attempted)
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

      # Extract the schema and function name from a PG::UndefinedFunction error message.
      #
      # @private
      # @param [Object] message The error message string
      # @return [Array<nil>, Object] Array of [schema, function_name] or [nil, nil] if not matched
      def arfi_extract_function_ident(message)
        m = message.to_s.match(ARFI_UNDEFINED_FUNCTION)
        return [nil, nil] unless m

        ident = m[1].to_s.delete('"')
        parts = ident.split(".", 2)
        parts.length == 2 ? [parts[0], parts[1]] : [nil, parts[0]]
      end

      # Check whether a function file exists under db/functions for the given schema and function name.
      #
      # @private
      # @param [Object] schema Schema name (possibly nil)
      # @param [Object] fn Function name
      # @return [Boolean, Object] Whether a matching file exists on disk
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
