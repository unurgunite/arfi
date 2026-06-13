# frozen_string_literal: true

module Arfi
  module Commands
    # Validation and doctor helpers for {Arfi::Commands::Functions}.
    module FunctionsDoctor
      include FunctionsDoctorRendering

      private

      # Validate all SQL function files by trying to execute them against a database connection.
      #
      # On PostgreSQL, each file is validated inside a transaction that is rolled back,
      # leaving the database state unchanged. On MySQL/Trilogy, DDL auto-commits,
      # so the functions will be loaded as a side effect of validation.
      #
      # @private
      # @return [void]
      def validate
        conn = prepare_connection

        files = discover_function_files(conn)
        if files.empty?
          puts 'No SQL function files found.'
          return
        end

        results = files.map { |file| validate_sql_file(conn, file) }
        report_validate_results(results)
      end

      # Compare functions on disk vs the database and report discrepancies.
      #
      # Shows each resolved function (highest-priority candidate per key) with its status:
      # - OK: function exists in the database
      # - MISSING: function file exists on disk but is not in the database
      #
      # @private
      # @return [void]
      def doctor
        conn = prepare_connection
        resolved = resolve_candidates
        results = resolved.map { |row| doctor_check_function(conn, row) }
        report_doctor_results(results)
      end

      # Run shared setup steps for validate/doctor commands.
      #
      # @private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      def prepare_connection
        validate_schema_format!
        validate_adapter_option!
        conn = establish_connection
        raise_unless_supported_adapter(conn)
        conn
      end

      # Resolve function candidates from disk for doctor.
      #
      # @private
      # @raise [Arfi::Errors::NoFunctionsDir]
      # @return [Array<Hash{Symbol => Object}>]
      def resolve_candidates
        root = Rails.root.join(ROOT_DIR)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        adapter = resolve_adapter
        candidates = collect_all_candidates(root, adapter)
        by_key = group_candidates_by_key(candidates)
        build_resolved_rows(by_key)
      end

      # Establish a database connection for validation/doctor operations.
      #
      # @private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      def establish_connection
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end

      # Raise unless the connection adapter is PostgreSQL, Mysql2, or Trilogy.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def raise_unless_supported_adapter(conn)
        allowed = %w[
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter
          ActiveRecord::ConnectionAdapters::TrilogyAdapter
        ].freeze

        raise Arfi::Errors::AdapterNotSupported unless allowed.include?(conn.class.name)
      end

      # Discover the effective set of SQL function files for the given connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @return [Array<String>] list of file paths
      def discover_function_files(conn)
        Arfi::SqlFunctionLoader.send(:sql_files, conn)
      end

      # Validate a single SQL file by executing it against the database.
      #
      # On PostgreSQL, wraps execution in a transaction with rollback to avoid side effects.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [String] file path to the SQL file
      # @raise [StandardError]
      # @return [Hash] result with :file, :status, and optionally :error keys
      def validate_sql_file(conn, file)
        sql = File.read(file.to_s).strip
        return { file: file, status: 'SKIP', error: 'File is empty' } if sql.empty?

        execute_sql_safely(conn, sql)
        { file: file, status: 'OK' }
      rescue StandardError => e
        { file: file, status: 'FAIL', error: e.message }
      end

      # Execute SQL safely inside a rollback transaction on PostgreSQL, or directly otherwise.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [String] sql SQL to execute
      # @raise [ActiveRecord::Rollback]
      # @return [void]
      def execute_sql_safely(conn, sql)
        if postgresql_adapter?(conn)
          conn.transaction do
            conn.execute(sql)
            raise ActiveRecord::Rollback
          end
        else
          conn.execute(sql)
        end
      end

      # Check whether the connection is PostgreSQL.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @return [Boolean]
      def postgresql_adapter?(conn)
        conn.instance_of?(::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      end

      # Check whether a resolved function exists in the database.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Hash{Symbol => Object}] row resolved function row from candidates
      # @param [Object] _conn Param documentation.
      # @return [Hash] result with :function, :schema, :status, :path keys
      def doctor_check_function(_conn, row)
        function_name = row[:function]
        schema = row[:schema]
        path = row[:path]
        exists = ActiveRecord::Base.function_exists?(function_name)

        { function: function_name, schema: schema, status: exists ? 'OK' : 'MISSING', path: path }
      end
    end
  end
end
