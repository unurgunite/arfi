# frozen_string_literal: true

module Arfi
  # +Arfi::SqlFunctionLoader+ loads user-defined SQL functions into the database.
  class SqlFunctionLoader
    class << self
      # Loads user defined SQL functions into database.
      #
      # @param task_name [String|nil] Name of the task.
      # @param clear_active_connections [Boolean] Whether to clear active connections in ensure.
      # @param verbose [Boolean] Whether to log per-file loads.
      def load!(task_name: nil, clear_active_connections: true, verbose: true)
        self.task_name = task_name[/([^:]+$)/] if task_name
        self.verbose = verbose

        raise_unless_supported_adapter

        if multi_db? && task_name.nil?
          populate_multiple_db
        else
          populate_db
        end
      ensure
        # Fine for task usage; not always safe for runtime retry paths.
        ActiveRecord::Base.clear_active_connections! if clear_active_connections && defined?(ActiveRecord::Base)
      end

      private

      def raise_unless_supported_adapter
        allowed = %w[
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter
        ].freeze

        return if allowed.include?(conn.class.to_s) # steep:ignore ArgumentTypeMismatch

        raise Arfi::Errors::AdapterNotSupported
      end

      def multi_db?
        ActiveRecord::Base.configurations.configurations.count { _1.env_name == Rails.env } > 1 # steep:ignore NoMethod
      end

      def populate_multiple_db
        # steep:ignore:start
        ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }.each do |config|
          ActiveRecord::Base.establish_connection(config)
          populate_db
        end
        # steep:ignore:end
      end

      def populate_db
        files = sql_files
        if files.empty?
          log("No SQL files found for adapter #{conn.class}. Skipping db population with ARFI")
          return
        end

        files.each do |file|
          sql = File.read(file).strip
          next if sql.empty?

          conn.execute(sql)

          next unless verbose

          log("[ARFI] Loaded: #{File.basename(file)} into #{conn.pool.db_config.env_name} #{conn.pool.db_config.name}")
        end
      end

      def log(msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

      # ONE-FILE-PER-FUNCTION resolver:
      # - generic: db/functions/*.sql
      # - adapter:  db/functions/postgresql/*.sql OR db/functions/mysql/*.sql
      # - adapter overrides generic by basename (same "function_name.sql")
      def sql_files
        root = Rails.root.join('db', 'functions')
        return [] unless root.directory?

        generic_glob = root.join('*.sql')
        adapter_glob  = adapter_glob_for(conn, root)

        files_by_name = {}

        Dir.glob(generic_glob.to_s).each do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          files_by_name[base] = path
        end

        Dir.glob(adapter_glob.to_s).each do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          files_by_name[base] = path
        end

        files_by_name.values.sort_by { |p| File.basename(p) }
      end

      def adapter_glob_for(conn, root)
        case conn
        when ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          root.join('postgresql', '*.sql')
        when ActiveRecord::ConnectionAdapters::Mysql2Adapter
          root.join('mysql', '*.sql')
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end

      def conn
        if Rails::VERSION::MAJOR < 7 || (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2)
          ActiveRecord::Base.connection
        else
          ActiveRecord::Base.lease_connection
        end
      end
    end
  end
end
