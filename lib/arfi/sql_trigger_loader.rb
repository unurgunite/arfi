# frozen_string_literal: true

module Arfi
  # Loads user-defined SQL triggers into the database by executing SQL files located under `db/triggers`.
  #
  # Mirror of {Arfi::SqlFunctionLoader} for triggers with `db/triggers` paths.
  class SqlTriggerLoader
    class << self
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

      def multi_db?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1
      end

      def raise_unless_supported_adapter(conn) # rubocop:disable SortedMethodsByCall/Waterfall
        allowed = %w[
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter
          ActiveRecord::ConnectionAdapters::TrilogyAdapter
        ].freeze

        raise Arfi::Errors::AdapterNotSupported unless allowed.include?(conn.class.name)
      end

      def populate_multiple_db(verbose:, task_name: nil)
        original = current_db_config
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db(default_connection, verbose: verbose, task_name: task_name)
        end
      ensure
        ActiveRecord::Base.establish_connection(original) if original
      end

      def default_connection
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end

      def current_db_config
        ActiveRecord::Base.connection_db_config
      rescue StandardError
        nil
      end

      def populate_db(conn, verbose:, task_name:)
        files = sql_files(conn)
        if files.empty?
          log(conn, "No SQL files found for adapter #{conn.class}. Skipping trigger loading")
          return
        end

        files.each { |file| load_sql_file(conn, file, verbose, task_name) }
      end

      def clear_active_connections_if_needed(clear)
        return unless clear && defined?(ActiveRecord::Base)

        if ActiveRecord::Base.respond_to?(:connection_handler) &&
           ActiveRecord::Base.connection_handler.respond_to?(:clear_active_connections!)
          ActiveRecord::Base.connection_handler.clear_active_connections!
        elsif ActiveRecord::Base.respond_to?(:clear_active_connections!)
          ActiveRecord::Base.clear_active_connections!
        end
      end

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

      def log_sql_load(conn, file, task_name)
        label = "[ARFI] Loaded trigger: #{File.basename(file)} into #{safe_db_env(conn)} #{safe_db_name(conn)}"
        label += " (#{task_name})" if task_name
        log(conn, label)
      end

      def safe_db_env(conn)
        conn.pool&.db_config&.env_name.to_s
      rescue StandardError
        ''
      end

      def safe_db_name(conn)
        conn.pool&.db_config&.name.to_s
      rescue StandardError
        ''
      end

      def log(_conn, msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

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

      def collect_adapter_public_sql_files(adapter_root)
        items = []
        items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
        items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)
        items
      end

      def collect_sql(glob:, schema:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          { schema: schema, base: base, path: path, priority: priority }
        end
      end

      def finalize_items(items)
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
