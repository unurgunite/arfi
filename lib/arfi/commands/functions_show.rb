# frozen_string_literal: true

module Arfi
  module Commands
    # Show function source for {Arfi::Commands::Functions}.
    module FunctionsShow
      private

      # Display the SQL source of a function from the database.
      #
      # @param [String] function_ref Function name (optionally schema-qualified)
      # @return [void]
      def display_source(function_ref)
        schema, function_name = parse_function_ref(function_ref)
        validate_identifiers!(schema, function_name)
        prepare_connection

        source = ActiveRecord::Base.function_source(function_name, schema: schema)
        if source.nil?
          raise Arfi::Errors::FunctionNotFound,
                "Function #{[schema, function_name].compact.join('.')} not found in database"
        end

        puts source
      end

      # Run shared setup steps for show command.
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

      # Establish a database connection for show operations.
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
    end
  end
end
