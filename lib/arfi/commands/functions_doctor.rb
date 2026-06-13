# frozen_string_literal: true

module Arfi
  module Commands
    # Validation and doctor helpers for {Arfi::Commands::Functions}.
    module FunctionsDoctor
      private

      # Validate all SQL function files by trying to execute them against a database connection.
      #
      # On PostgreSQL, each file is validated inside a transaction that is rolled back,
      # leaving the database state unchanged. On MySQL/Trilogy, DDL auto-commits,
      # so the functions will be loaded as a side effect of validation.
      #
      # @return [void]
      def validate
        validate_schema_format!
        validate_adapter_option!

        resolve_adapter
        conn = establish_connection

        raise_unless_supported_adapter(conn)

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
      # @return [void]
      def doctor
        validate_schema_format!
        validate_adapter_option!

        adapter = resolve_adapter
        conn = establish_connection

        raise_unless_supported_adapter(conn)

        root = Rails.root.join(ROOT_DIR)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        candidates = collect_all_candidates(root, adapter)
        by_key = group_candidates_by_key(candidates)
        resolved = build_resolved_rows(by_key)

        results = resolved.map { |row| doctor_check_function(conn, row) }
        report_doctor_results(results)
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
      # @return [Hash] result with :file, :status, and optionally :error keys
      def validate_sql_file(conn, file)
        sql = File.read(file.to_s).strip
        return { file: file, status: 'SKIP', error: 'File is empty' } if sql.empty?

        if postgresql_adapter?(conn)
          conn.transaction do
            conn.execute(sql)
            raise ActiveRecord::Rollback
          end
        else
          conn.execute(sql)
        end

        { file: file, status: 'OK' }
      rescue StandardError => e
        { file: file, status: 'FAIL', error: e.message }
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
      # @param [Hash<Symbol, Object>] row resolved function row from candidates
      # @return [Hash] result with :function, :schema, :status, :path keys
      def doctor_check_function(_conn, row)
        function_name = row[:function]
        schema = row[:schema]
        path = row[:path]

        exists = ActiveRecord::Base.function_exists?(function_name)

        { function: function_name, schema: schema, status: exists ? 'OK' : 'MISSING', path: path }
      end

      # Render validation results in the selected output format.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def report_validate_results(results)
        case options[:format].to_s
        when 'json'
          puts JSON.pretty_generate(results.map { |r| format_validate_result(r) })
        when 'paths'
          results.each { |r| puts "#{rel(r[:file])}  #{r[:status]}" }
        else
          print_validate_table(results)
        end
      end

      # Format a validation result for JSON output.
      #
      # @private
      # @param [Hash] r
      # @return [Hash]
      def format_validate_result(r)
        { file: rel(r[:file]), status: r[:status], error: r[:error] }.compact
      end

      # Print validation results as an ASCII table.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def print_validate_table(results)
        cols = %w[file status error]
        rows = results.map do |r|
          { file: rel(r[:file]), status: r[:status], error: r[:error] || '' }
        end
        widths = calculate_col_widths(cols, rows)
        print_separator(cols, widths)
        rows.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Render doctor results in the selected output format.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def report_doctor_results(results)
        case options[:format].to_s
        when 'json'
          puts JSON.pretty_generate(results)
        when 'paths'
          results.each { |r| puts "#{rel(r[:path])}  #{r[:status]}" }
        else
          print_doctor_table(results)
        end
      end

      # Print doctor results as an ASCII table.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def print_doctor_table(results)
        cols = %w[function schema status path]
        rows = results.map do |r|
          { function: r[:function], schema: r[:schema], status: r[:status], path: rel(r[:path]) }
        end
        widths = calculate_col_widths(cols, rows)
        print_separator(cols, widths)
        rows.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Calculate column widths for a table.
      #
      # @private
      # @param [Array<String>] cols column names
      # @param [Array<Hash>] rows
      # @return [Hash<String, Integer>]
      def calculate_col_widths(cols, rows)
        widths = {}
        cols.each do |c|
          widths[c] = ([c.length] + rows.map { |r| r[c.to_sym].to_s.length }).max
        end
        widths
      end

      # Print table header and separator line.
      #
      # @private
      # @param [Array<String>] cols
      # @param [Hash<String, Integer>] widths
      # @return [void]
      def print_separator(cols, widths)
        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')
      end
    end
  end
end
