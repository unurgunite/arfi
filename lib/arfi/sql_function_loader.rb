# frozen_string_literal: true

module Arfi
  # Loads user-defined SQL functions into the database.
  #
  # Supported directory layout (Option B: explicit public):
  #
  #   db/functions/public/*.sql                       (generic public)
  #   db/functions/postgresql/public/*.sql            (postgres public)
  #   db/functions/postgresql/<schema>/*.sql          (postgres schema)
  #
  # Backward-compatible legacy aliases:
  #
  #   db/functions/*.sql                              (generic public legacy)
  #   db/functions/postgresql/*.sql                   (postgres public legacy)
  #
  # Rules:
  # - underscore-prefixed files are ignored (_shared.sql)
  # - adapter-specific overrides generic when schema+filename matches
  class SqlFunctionLoader
    class << self
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

      attr_accessor :task_name, :verbose

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
          ActiveRecord::Base.establish_connection(config.config)
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

          if verbose
            log("[ARFI] Loaded: #{File.basename(file)} into #{conn.pool.db_config.env_name} #{conn.pool.db_config.name}")
          end
        end
      end

      def log(msg)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.info(msg)
        else
          $stdout.puts(msg)
        end
      end

      # Returns final ordered list of SQL file paths to execute.
      #
      # Deduping key:
      # - PostgreSQL: [schema, basename]
      # - Others:    ["public", basename]
      #
      # Priority (higher wins):
      #  10: adapter explicit schema dir (postgresql/<schema>/fn.sql)
      #   9: adapter explicit public dir (postgresql/public/fn.sql)
      #   8: adapter legacy public       (postgresql/fn.sql)
      #   2: generic explicit public     (public/fn.sql)
      #   1: generic legacy public       (fn.sql)
      def sql_files
        root = Rails.root.join('db', 'functions')
        return [] unless root.directory?

        items = []

        # Generic public (legacy + explicit)
        items.concat collect_sql(glob: root.join('*.sql'), schema: 'public', priority: 1)
        items.concat collect_sql(glob: root.join('public', '*.sql'), schema: 'public', priority: 2)

        adapter_root = adapter_root_for(conn, root)
        return finalize_items(items) if adapter_root.nil? || !adapter_root.directory?

        case conn
        when ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          # Adapter public (legacy + explicit)
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
        when ActiveRecord::ConnectionAdapters::Mysql2Adapter
          # Keep old behavior; also allow mysql/public if present.
          items.concat collect_sql(glob: adapter_root.join('*.sql'), schema: 'public', priority: 8)
          items.concat collect_sql(glob: adapter_root.join('public', '*.sql'), schema: 'public', priority: 9)
        else
          raise Arfi::Errors::AdapterNotSupported
        end

        finalize_items(items)
      end

      def collect_sql(glob:, schema:, priority:)
        Dir.glob(glob.to_s).map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          { schema: schema, base: base, path: path, priority: priority }
        end.compact
      end

      def finalize_items(items)
        chosen = {}

        items.each do |it|
          key = "#{it[:schema]}/#{it[:base]}"
          prev = chosen[key]
          chosen[key] = it if prev.nil? || it[:priority] > prev[:priority]
        end

        chosen.values
              .sort_by { |it| [it[:schema], it[:base]] } # deterministic
              .map { |it| it[:path] }
      end

      def adapter_root_for(conn, root)
        case conn
        when ActiveRecord::ConnectionAdapters::PostgreSQLAdapter then root.join('postgresql')
        when ActiveRecord::ConnectionAdapters::Mysql2Adapter     then root.join('mysql')
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
