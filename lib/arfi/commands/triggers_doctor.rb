# frozen_string_literal: true

module Arfi
  module Commands
    # Validation and doctor helpers for {Arfi::Commands::Triggers}.
    module TriggersDoctor
      include TriggersDoctorRendering

      private

      # Validate all SQL trigger files by executing them against the database.
      #
      # On PostgreSQL, each file is validated inside a transaction that is rolled back,
      # leaving the database state unchanged. On MySQL/Trilogy, DDL auto-commits,
      # so triggers will be loaded as a side effect of validation.
      #
      # @private
      # @return [void]
      def validate
        conn = prepare_connection

        files = discover_trigger_files(conn)
        if files.empty?
          puts 'No SQL trigger files found.'
          return
        end

        results = files.map { |file| validate_sql_file(conn, file) }
        report_validate_results(results)
      end

      # Compare trigger files on disk vs the database and report discrepancies.
      #
      # Shows each resolved trigger (highest-priority candidate per key) with its status:
      # - OK: trigger exists in the database
      # - MISSING: trigger file exists on disk but is not in the database
      #
      # @private
      # @return [void]
      def doctor
        conn = prepare_connection
        resolved = resolve_candidates
        results = resolved.map { |row| doctor_check_trigger(conn, row) }
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

      # Resolve trigger candidates from disk for doctor.
      #
      # @private
      # @raise [Arfi::Errors::NoTriggersDir]
      # @return [Array<Hash{Symbol => Object}>]
      def resolve_candidates
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        raise Arfi::Errors::NoTriggersDir unless root.directory?

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

      # Discover the effective set of SQL trigger files for the given connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @return [Array<String>] list of file paths
      def discover_trigger_files(conn)
        Arfi::SqlTriggerLoader.send(:sql_files, conn)
      end

      # Validate a single SQL trigger file by executing it against the database.
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

      # Check whether a resolved trigger exists in the database.
      #
      # Extracts the target table name from the SQL file to call {ActiveRecord::Base.trigger_exists?}.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] _conn
      # @param [Hash{Symbol => Object}] row resolved trigger row from candidates
      # @return [Hash] result with :trigger, :schema, :table, :status, :path keys
      def doctor_check_trigger(_conn, row)
        trigger_name = row[:trigger]
        schema = row[:schema]
        path = row[:path]
        table = extract_table_from_sql(path)
        exists = table && ActiveRecord::Base.trigger_exists?(table, trigger_name)

        { trigger: trigger_name, schema: schema, status: exists ? 'OK' : 'MISSING',
          table: table || '?', path: path }
      end

      # Parse the target table name from a CREATE TRIGGER SQL file.
      #
      # Extracts the identifier following the ON keyword.
      #
      # @private
      # @param [String] path path to the SQL file
      # @raise [StandardError] if file cannot be read
      # @return [String, nil] table name or nil if parsing fails
      def extract_table_from_sql(path)
        sql = File.read(path.to_s)
        match = sql.match(/ON\s+(?:\w+\.)?(\w+)/im)
        match&.[](1)
      rescue StandardError
        nil
      end
    end
  end
end
