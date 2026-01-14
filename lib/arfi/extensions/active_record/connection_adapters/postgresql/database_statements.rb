# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/database_statements"
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
      rescue ::PG::UndefinedFunction => e
        # Avoid infinite loops if reload doesn't fix it (or reload itself errors).
        raise if Thread.current[THREAD_GUARD_KEY]

        fn = arfi_extract_function_name(e.message)

        # Only attempt recovery if the function is managed by ARFI (file exists).
        raise unless arfi_has_function_file_for?(fn)

        Thread.current[THREAD_GUARD_KEY] = true
        begin
          # Reload function definitions for the *current* connection only.
          # Passing task_name forces loader into "single target DB" behavior in multi-db apps.
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

      def arfi_extract_function_name(message)
        m = message.match(ARFI_UNDEFINED_FUNCTION)
        return nil unless m
        m[1].to_s.split(".").last.delete('"')
      end

      def arfi_has_function_file_for?(function_name)
        return false if function_name.nil? || function_name.empty?

        root = Rails.root.join("db", "functions")
        return false unless root.directory?

        File.exist?(root.join("#{function_name}.sql")) ||
          File.exist?(root.join("postgresql", "#{function_name}.sql"))
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQL::DatabaseStatements.prepend(
  Arfi::PostgreSQL::DatabaseStatementsPatch
)
