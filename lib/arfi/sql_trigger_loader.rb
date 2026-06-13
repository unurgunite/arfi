# frozen_string_literal: true

module Arfi
  # Loads user-defined SQL triggers into the database by executing SQL files located under `db/triggers`.
  #
  # Mirror of {Arfi::SqlFunctionLoader} for triggers with `db/triggers` paths.
  class SqlTriggerLoader
    class << self
      # Loads all trigger SQL files into the database for the current adapter.
      #
      # Handles multi-DB setups by iterating all configurations when no specific
      # connection or task_name is given.
      #
      # @param [String?] task_name Rake task name for logging
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter?] connection optional specific connection
      # @param [Boolean] clear_active_connections whether to clear connections after loading
      # @param [Boolean] verbose whether to log each loaded file
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

      # Returns true if more than one database configuration exists for the current env.
      #
      # @private
      # @return [Boolean]
      def multi_db?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1
      end

      # Raises unless the connection adapter is one of the supported types.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def raise_unless_supported_adapter(conn) # rubocop:disable SortedMethodsByCall/Waterfall
        allowed = %w[
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter
          ActiveRecord::ConnectionAdapters::TrilogyAdapter
        ].freeze

        raise Arfi::Errors::AdapterNotSupported unless allowed.include?(conn.class.name)
      end

      # Iterates all database configs for the current env and loads triggers into each.
      #
      # Restores the original connection after loading.
      #
      # @private
      # @param [Boolean] verbose
      # @param [String?] task_name
      # @return [void]
      def populate_multiple_db(verbose:, task_name: nil)
        original = current_db_config
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db(default_connection, verbose: verbose, task_name: task_name)
        end
      ensure
        ActiveRecord::Base.establish_connection(original) if original
      end

      # Returns the default ActiveRecord connection, handling the lease_connection API change.
      #
      # @private
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      def default_connection
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end

      # Returns the current database config object, or nil on error.
      #
      # @private
      # @raise [StandardError]
      # @return [Object] ActiveRecord::DatabaseConfigurations::HashConfig or similar
      def current_db_config
        ActiveRecord::Base.connection_db_config
      rescue StandardError
        nil
      end

      # Loads all SQL trigger files for a single connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Boolean] verbose
      # @param [String?] task_name
      # @return [void]
      def populate_db(conn, verbose:, task_name:)
        files = sql_files(conn)
        if files.empty?
          log(conn, "No SQL files found for adapter #{conn.class}. Skipping trigger loading")
          return
        end

        files.each { |file| load_sql_file(conn, file, verbose, task_name) }
      end

      # Clears all active connections unless suppressed by caller.
      #
      # Handles both old and new ActiveRecord connection handler APIs.
      #
      # @private
      # @param [Boolean] clear whether to actually clear
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

      # Executes a single SQL file against the given connection.
      #
      # Re-raises with the file path appended to the error message on failure.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Pathname, String] file path to the SQL file
      # @param [Boolean] verbose
      # @param [String?] task_name
      # @raise [StandardError] on SQL execution failure
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

      # Logs a successful trigger load to Rails logger or stdout.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Pathname, String] file path to the loaded SQL file
      # @param [String?] task_name
      # @return [void]
      def log_sql_load(conn, file, task_name)
        label = "[ARFI] Loaded trigger: #{File.basename(file)} into #{safe_db_env(conn)} #{safe_db_name(conn)}"
        label += " (#{task_name})" if task_name
        log(conn, label)
      end

      # Safely returns the database environment name, or empty string on error.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @raise [StandardError]
      # @return [String]
      def safe_db_env(conn)
        conn.pool&.db_config&.env_name.to_s
      rescue StandardError
        ''
      end

      # Safely returns the database config name, or empty string on error.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @raise [StandardError]
      # @return [String]
      def safe_db_name(conn)
        conn.pool&.db_config&.name.to_s
      rescue StandardError
        ''
      end

      # Logs a message via Rails logger or stdout.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] _conn (unused, kept for interface consistency)
      # @param [String] msg message to log
      # @return [void]
      def log(_conn, msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

      # Discovers and returns SQL trigger files for the given connection's adapter.
      #
      # Merges generic and adapter-specific files, deduplicating by priority.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @return [Array<String>] sorted list of file paths
      def sql_files(conn)
        root = Rails.root.join('db', 'triggers')
        return [] unless root.directory?

        generic = [
          collect_sql(glob: root.join('*.sql'), schema: 'public', priority: 1),
          collect_sql(glob: root.join('public', '*.sql'), schema: 'public', priority: 2)
        ].flatten

        adapter_root = adapter_root_for(conn, root)
        return finalize_items(generic) unless adapter_root&.directory?

        finalize_items(generic + collect_adapter_sql_files(conn, adapter_root))
      end

      # Collects adapter-specific SQL files, dispatching by connection class.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Pathname] adapter_root db/triggers/<adapter>
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [Array<Arfi::sql_file_item>]
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

      # Collects PostgreSQL SQL files, including schema-specific subdirectories.
      #
      # @private
      # @param [Pathname] adapter_root db/triggers/postgresql
      # @return [Array<Arfi::sql_file_item>]
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

      # Collects adapter SQL files from the root and public/ subdirectory.
      #
      # @private
      # @param [Pathname] adapter_root db/triggers/<adapter>
      # @return [Array<Arfi::sql_file_item>]
      def collect_adapter_public_sql_files(adapter_root)
        items = [] # steep:ignore
        items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
        items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)
        items
      end

      # Collects SQL file items from a glob pattern.
      #
      # Skips files starting with underscore (disabled).
      #
      # @private
      # @param [Pathname, String] glob glob pattern
      # @param [String] schema schema name
      # @param [Integer] priority priority for deduplication
      # @return [Array<Arfi::sql_file_item>]
      def collect_sql(glob:, schema:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          { schema: schema, base: base, path: path, priority: priority }
        end
      end

      # Deduplicates items by key (schema/base), keeping the highest-priority each.
      #
      # Returns sorted file paths.
      #
      # @private
      # @param [Array<Arfi::sql_file_item>] items all discovered items
      # @return [Array<String>] sorted, deduplicated file paths
      def finalize_items(items)
        chosen = {} # steep:ignore

        items.each do |item|
          key = "#{item[:schema]}/#{item[:base]}"
          prev = chosen[key]
          chosen[key] = item if prev.nil? || item[:priority] > prev[:priority]
        end

        chosen.values
              .sort_by { |item| [item[:schema], item[:base]] }
              .map { |item| item[:path] }
      end

      # Returns the adapter-specific subdirectory under db/triggers for the given connection.
      #
      # @private
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter] conn
      # @param [Pathname] root db/triggers
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [Pathname]
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
