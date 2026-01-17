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
      # +Arfi::SqlFunctionLoader.load!+ -> Object
      #
      # Load SQL functions into the database.
      #
      # If `connection:` is provided, ARFI loads into that specific connection (useful for runtime retry paths).
      # Otherwise ARFI uses the default ActiveRecord connection. In multi-db Rails apps, when `task_name` is nil
      # and `connection` is nil, ARFI loads functions into all configured databases for the current env.
      #
      # @param [String, nil] task_name Param documentation.
      # @param [ActiveRecord::ConnectionAdapters::AbstractAdapter, nil] connection Param documentation.
      # @param [Boolean] clear_active_connections Param documentation.
      # @param [Boolean] verbose Param documentation.
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def load!(task_name: nil, connection: nil, clear_active_connections: true, verbose: true)
        task_short = task_name ? task_name[/([^:]+$)/] : nil
        conn = connection || default_connection

        raise_unless_supported_adapter(conn)

        if connection.nil? && multi_db? && task_name.nil?
          populate_multiple_db(verbose: verbose)
        else
          populate_db(conn, verbose: verbose, task_name: task_short)
        end
      ensure
        # +Arfi::SqlFunctionLoader.load!+ -> Object
        #
        # Ensure clause: optionally clears active connections.
        #
        # @private
        # @return [void]
        if clear_active_connections && defined?(ActiveRecord::Base)
          if ActiveRecord::Base.respond_to?(:connection_handler) &&
             ActiveRecord::Base.connection_handler.respond_to?(:clear_active_connections!)
            ActiveRecord::Base.connection_handler.clear_active_connections!
          elsif ActiveRecord::Base.respond_to?(:clear_active_connections!)
            # Older Rails fallback
            ActiveRecord::Base.clear_active_connections!
          end
        end
      end

      private

      # +Arfi::SqlFunctionLoader.raise_unless_supported_adapter+ -> Object
      #
      # Validate adapter support for the given connection.
      #
      # @private
      # @param [Object] conn Param documentation.
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

      # +Arfi::SqlFunctionLoader.multi_db?+ -> Object
      #
      # Determine whether the current Rails environment has more than one DB configuration.
      #
      # @private
      # @return [Boolean]
      def multi_db?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1 # steep:ignore NoMethod
      end

      # +Arfi::SqlFunctionLoader.populate_multiple_db+ -> Object
      #
      # Load functions into each configured DB for current env.
      #
      # @private
      # @param [Boolean] verbose Param documentation.
      # @return [void]
      def populate_multiple_db(verbose:)
        # steep:ignore:start
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db(default_connection, verbose: verbose, task_name: nil)
        end
        # steep:ignore:end
      end

      # +Arfi::SqlFunctionLoader.populate_db+ -> Object
      #
      # Load SQL function files into a specific connection.
      #
      # @private
      # @param [Object] conn Param documentation.
      # @param [Boolean] verbose Param documentation.
      # @param [String, nil] task_name Param documentation.
      # @return [void]
      def populate_db(conn, verbose:, task_name:)
        files = sql_files(conn)
        if files.empty?
          log(conn, "No SQL files found for adapter #{conn.class}. Skipping db population with ARFI")
          return
        end

        files.each do |file|
          sql = File.read(file).strip
          next if sql.empty?

          begin
            conn.execute(sql)
          rescue StandardError => e
            raise e.class, "#{e.message}\n[ARFI] while loading #{file}", e.backtrace
          end

          next unless verbose

          env = safe_db_env(conn)
          name = safe_db_name(conn)
          log(conn, "[ARFI] Loaded: #{File.basename(file)} into #{env} #{name}#{" (#{task_name})" if task_name}")
        end
      end

      # +Arfi::SqlFunctionLoader.safe_db_env+ -> Object
      #
      # Extract the DB env name for logging.
      #
      # @private
      # @param [Object] conn Param documentation.
      # @return [String]
      def safe_db_env(conn)
        conn.pool&.db_config&.env_name.to_s
      rescue StandardError
        ''
      end

      # +Arfi::SqlFunctionLoader.safe_db_name+ -> Object
      #
      # Extract the DB name for logging.
      #
      # @private
      # @param [Object] conn Param documentation.
      # @return [String]
      def safe_db_name(conn)
        conn.pool&.db_config&.name.to_s
      rescue StandardError
        ''
      end

      # +Arfi::SqlFunctionLoader.log+ -> Object
      #
      # Log a message to Rails.logger if present, otherwise stdout.
      #
      # @private
      # @param [Object] _conn Param documentation.
      # @param [Object] msg Param documentation.
      # @return [void]
      def log(_conn, msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

      # +Arfi::SqlFunctionLoader.sql_files+ -> Object
      #
      # Build the final ordered list of SQL files to execute for the given connection.
      #
      # Priority (higher wins):
      #  10: adapter explicit schema dir (postgresql/<schema>/fn.sql)
      #   9: adapter explicit public dir (postgresql/public/fn.sql)
      #   8: adapter legacy public       (postgresql/fn.sql)
      #   2: generic explicit public     (public/fn.sql)
      #   1: generic legacy public       (fn.sql)
      #
      # @private
      # @param [Object] conn Param documentation.
      # @return [Array<String>]
      def sql_files(conn)
        root = Rails.root.join('db', 'functions')
        return [] unless root.directory?

        # @type var items: Array[{ schema: String, base: String, path: String, priority: Integer }]
        items = []

        # Generic public (legacy + explicit)
        items.concat collect_sql(glob: root.join('*.sql'), schema: 'public', priority: 1)
        items.concat collect_sql(glob: root.join('public', '*.sql'), schema: 'public', priority: 2)

        adapter_root = adapter_root_for(conn, root)
        return finalize_items(items) if adapter_root.nil? || !adapter_root.directory?

        case conn.class.name
        when 'ActiveRecord::ConnectionAdapters::PostgreSQLAdapter'
          items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
          items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)

          # Adapter schema dirs (explicit): db/functions/postgresql/<schema>/*.sql
          Dir.children(adapter_root).sort.each do |child|
            next if child.start_with?('_')
            next if child == 'public'

            dir = adapter_root.join(child)
            next unless dir.directory?

            items.concat collect_sql(glob: dir.join('*.sql'), schema: child, priority: 10)
          end
        when 'ActiveRecord::ConnectionAdapters::Mysql2Adapter', 'ActiveRecord::ConnectionAdapters::TrilogyAdapter'
          items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
          items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)
        else
          raise Arfi::Errors::AdapterNotSupported
        end

        finalize_items(items)
      end

      # +Arfi::SqlFunctionLoader.collect_sql+ -> Object
      #
      # Collect SQL file candidates for a given glob, schema name, and priority.
      #
      # @private
      # @param [Object] glob Param documentation.
      # @param [Object] schema Param documentation.
      # @param [Object] priority Param documentation.
      # @return [Array<Hash>]
      def collect_sql(glob:, schema:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          { schema: schema, base: base, path: path, priority: priority }
        end
      end

      # +Arfi::SqlFunctionLoader.finalize_items+ -> Object
      #
      # Deduplicate and deterministically order SQL file candidates by (schema, filename), keeping the highest priority.
      #
      # @private
      # @param [Object] items Param documentation.
      # @return [Array<String>]
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

      # +Arfi::SqlFunctionLoader.adapter_root_for+ -> Object
      #
      # Resolve adapter directory under db/functions for the given connection.
      #
      # @private
      # @param [Object] conn Param documentation.
      # @param [Object] root Param documentation.
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

      # +Arfi::SqlFunctionLoader.default_connection+ -> Object
      #
      # Get the default ActiveRecord connection across Rails versions.
      #
      # @private
      # @return [Object]
      def default_connection
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end
    end
  end
end
