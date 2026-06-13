# frozen_string_literal: true

module Arfi
  # Loads user-defined SQL functions into the database by executing SQL files located under `db/functions`.
  #
  # Supported directory layout (Option B: explicit public):
  #
  #   db/functions/public/*.sql                       (generic public)
  #   db/functions/postgresql/public/*.sql            (postgres public)
  #   db/functions/postgresql/<schema>/*.sql          (postgres schema)
  #   db/functions/mysql/public/*.sql                 (mysql/trilogy public)
  #
  # Backward-compatible legacy aliases:
  #
  #   db/functions/*.sql                              (generic public legacy)
  #   db/functions/postgresql/*.sql                   (postgres public legacy)
  #   db/functions/mysql/*.sql                        (mysql public legacy)
  #
  # Rules:
  # - underscore-prefixed files are ignored (_shared.sql)
  # - adapter-specific overrides generic when schema+filename matches
  #
  # @api public
  class SqlFunctionLoader
    class << self
      # Load all SQL function files into the database.
      #
      # Handles both single-DB and multi-DB setups. Uses the given connection or infers it.
      #
      # @param [String?] task_name Optional task name for logging (e.g. 'db:migrate')
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter?] connection Specific connection to load into
      # @param [Boolean] clear_active_connections Whether to clear connections after loading
      # @param [Boolean] verbose Whether to log each loaded file
      # @return [void]
      def load!(task_name: nil, connection: nil, clear_active_connections: true, verbose: true)
        task_short = task_name ? task_name[/([^:]+$)/] : nil
        conn = connection || default_connection

        raise_unless_supported_adapter(conn)

        if connection.nil? && multi_db? && task_name.nil?
          populate_multiple_db(verbose: verbose, task_name: task_short)
        else
          populate_db(conn, verbose: verbose, task_name: task_short)
        end
      ensure
        clear_active_connections_if_needed(clear_active_connections)
      end

      private

      # Raise unless the connection adapter is one of the supported types.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not PostgreSQL, Mysql2, or Trilogy
      # @return [void]
      def raise_unless_supported_adapter(conn) # rubocop:disable SortedMethodsByCall/Waterfall
        allowed = %w[
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter
          ActiveRecord::ConnectionAdapters::TrilogyAdapter
        ].freeze

        raise Arfi::Errors::AdapterNotSupported unless allowed.include?(conn.class.name)
      end

      # Check whether the Rails app has multiple database configurations for the current environment.
      #
      # @private
      # @return [Boolean] Whether multi-DB is configured
      def multi_db?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1 # steep:ignore NoMethod
      end

      # Load functions into all databases in a multi-DB setup.
      #
      # Saves the original connection and restores it after iterating all configs,
      # matching the pattern used in `run_with_connection_switch` (db.rake).
      #
      # @private
      # @param [Boolean] verbose Whether to log each loaded file
      # @param [String?] task_name Optional task name for logging
      # @return [void]
      def populate_multiple_db(verbose:, task_name: nil)
        original = current_db_config
        # steep:ignore:start
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db(default_connection, verbose: verbose, task_name: task_name)
        end
        # steep:ignore:end
      ensure
        ActiveRecord::Base.establish_connection(original) if original
      end

      # Get the default database connection, handling Rails version differences.
      #
      # @private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter] Default connection
      def default_connection
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end

      # Get the current database config, or nil if no connection is established.
      #
      # @private
      # @return [ActiveRecord::DatabaseConfig, nil] Current database config
      def current_db_config
        ActiveRecord::Base.connection_db_config # steep:ignore NoMethod
      rescue StandardError
        nil
      end

      # Load SQL function files into a single database connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @param [Boolean] verbose Whether to log each loaded file
      # @param [String?] task_name Optional task name for logging
      # @return [void]
      def populate_db(conn, verbose:, task_name:)
        files = sql_files(conn)
        if files.empty?
          log(conn, "No SQL files found for adapter #{conn.class}. Skipping db population with ARFI")
          return
        end

        files.each { |file| load_sql_file(conn, file, verbose, task_name) }
      end

      # Clear all active database connections if requested, handling Rails version differences.
      #
      # @private
      # @param [Boolean] clear Whether to clear connections
      # @return [void]
      def clear_active_connections_if_needed(clear)
        return unless clear && defined?(ActiveRecord::Base)

        if ActiveRecord::Base.respond_to?(:connection_handler) &&
           ActiveRecord::Base.connection_handler.respond_to?(:clear_active_connections!)
          ActiveRecord::Base.connection_handler.clear_active_connections!
        elsif ActiveRecord::Base.respond_to?(:clear_active_connections!)
          ActiveRecord::Base.clear_active_connections!
        end
      end

      # Load a single SQL file into the database, wrapping errors with file context.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @param [Pathname, String] file Path to the SQL file
      # @param [Boolean] verbose Whether to log the loaded file
      # @param [String?] task_name Optional task name for logging
      # @raise [StandardError] If the SQL execution fails (re-raised with file context)
      # @return [void]
      def load_sql_file(conn, file, verbose, task_name)
        sql = File.read(file.to_s).strip
        return if sql.empty?

        begin
          conn.execute(sql)
        rescue StandardError => e
          raise e.class, "#{e.message}\n[ARFI] while loading #{file}", e.backtrace
        end
        return unless verbose

        log_sql_load(conn, file, task_name)
      end

      # Log that a SQL file was successfully loaded into the database.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @param [Pathname, String] file Path to the loaded SQL file
      # @param [String?] task_name Optional task name for logging
      # @return [void]
      def log_sql_load(conn, file, task_name)
        label = "[ARFI] Loaded: #{File.basename(file)} into #{safe_db_env(conn)} #{safe_db_name(conn)}"
        label += " (#{task_name})" if task_name
        log(conn, label)
      end

      # Get the database environment name safely, returning empty string on error.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @raise [StandardError]
      # @return [String] Environment name, or empty string on error
      # @return [String] if StandardError
      def safe_db_env(conn)
        conn.pool&.db_config&.env_name.to_s
      rescue StandardError
        ''
      end

      # Get the database name safely, returning empty string on error.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @raise [StandardError]
      # @return [String] Database name, or empty string on error
      # @return [String] if StandardError
      def safe_db_name(conn)
        conn.pool&.db_config&.name.to_s
      rescue StandardError
        ''
      end

      # Log a message via Rails.logger or stdout.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] _conn Database connection (unused)
      # @param [String] msg Message to log
      # @return [void]
      def log(_conn, msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

      # Collect all SQL files to load for the given connection, applying override resolution.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @return [Array<String>] Ordered list of SQL file paths
      def sql_files(conn)
        root = Rails.root.join('db', 'functions')
        return [] unless root.directory?

        generic = [
          collect_sql(glob: root.join('*.sql'), schema: 'public', priority: 1),
          collect_sql(glob: root.join('public', '*.sql'), schema: 'public', priority: 2)
        ].flatten

        adapter_root = adapter_root_for(conn, root)
        return finalize_items(generic) unless adapter_root&.directory?

        finalize_items(generic + collect_adapter_sql_files(conn, adapter_root))
      end

      # Collect adapter-specific SQL files, dispatching to the correct strategy based on adapter type.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @param [Pathname] adapter_root Adapter root directory (e.g. db/functions/postgresql)
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not supported
      # @return [Array<Arfi::sql_file_item>] List of SQL file items
      def collect_adapter_sql_files(conn, adapter_root)
        case conn.class.name
        when 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
          collect_postgresql_sql_files(adapter_root)
        when 'ActiveRecord::ConnectionAdapters::Mysql2Adapter', 'ActiveRecord::ConnectionAdapters::TrilogyAdapter'
          collect_adapter_public_sql_files(adapter_root)
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end

      # Collect SQL files for PostgreSQL, including schema subdirectories.
      #
      # @private
      # @param [Pathname] adapter_root PostgreSQL adapter root directory
      # @return [Array<Arfi::sql_file_item>] List of SQL file items
      def collect_postgresql_sql_files(adapter_root)
        items = collect_adapter_public_sql_files(adapter_root)

        Dir.children(adapter_root).sort.each do |child|
          next if child.start_with?('_')
          next if child == 'public'

          dir = adapter_root.join(child)
          next unless dir.directory?

          items.concat collect_sql(glob: dir.join('*.sql'), schema: child, priority: 10)
        end

        items
      end

      # Collect SQL files from the adapter's public directory (legacy + explicit).
      #
      # @private
      # @param [Pathname] adapter_root Adapter root directory
      # @return [Array<Arfi::sql_file_item>] List of SQL file items
      def collect_adapter_public_sql_files(adapter_root)
        items = [] # steep:ignore
        items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
        items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)
        items
      end

      # Collect SQL files matching a glob pattern, skipping underscore-prefixed files.
      #
      # @private
      # @param [Pathname, String] glob Glob pattern to match SQL files
      # @param [String] schema Schema name to assign to matched files
      # @param [Integer] priority Priority for override resolution (higher = preferred)
      # @return [Array<Arfi::sql_file_item>] List of SQL file items
      def collect_sql(glob:, schema:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          { schema: schema, base: base, path: path, priority: priority }
        end
      end

      # Finalize the file list by selecting the highest-priority item per schema/filename key.
      #
      # @private
      # @param [Array<Arfi::sql_file_item>] items All collected SQL file items
      # @return [Array<String>] Ordered list of chosen file paths
      def finalize_items(items)
        # @type var chosen: Hash[String, { schema: String, base: String, path: String, priority: Integer }]
        chosen = {}

        items.each do |item|
          key = "#{item[:schema]}/#{item[:base]}"
          prev = chosen[key]
          chosen[key] = item if prev.nil? || item[:priority] > prev[:priority]
        end

        chosen.values
              .sort_by { |item| [item[:schema], item[:base]] }
              .map { |item| item[:path] }
      end

      # Resolve the adapter-specific root directory for the given connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn Database connection
      # @param [Pathname] root Project root (db/functions)
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not supported
      # @return [Pathname] Adapter root directory
      def adapter_root_for(conn, root)
        case conn.class.name
        when 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
          root.join('postgresql')
        when 'ActiveRecord::ConnectionAdapters::Mysql2Adapter',
          'ActiveRecord::ConnectionAdapters::TrilogyAdapter'
          root.join('mysql')
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end
    end
  end
end
