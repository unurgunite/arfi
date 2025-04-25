# frozen_string_literal: true

module Arfi
  # +Arfi::SqlFunctionLoader+ is a class which loads user defined SQL functions into database.
  class SqlFunctionLoader
    class << self
      def load!
        return unless sql_files&.any?

        puts '[ARFI] Loading SQL functions BEFORE schema load transaction...'
        db_config = Rails.configuration.database_configuration[Rails.env]
        conn = conn(db_config)

        sql_files&.each do |file|
          sql = File.read(file).strip
          conn.exec(sql)
          puts "[ARFI] Loaded: #{File.basename(file)}"
        end

        conn.close
      end

      private

      def sql_files
        Dir.glob(Rails.root.join('db', 'functions').join('*.sql'))
      end

      def conn(db_config)
        PG.connect(
          user: db_config['username'],
          password: db_config['password'],
          host: db_config['host'],
          port: db_config['port'],
          dbname: db_config['database']
        )
      end
    end
  end
end
