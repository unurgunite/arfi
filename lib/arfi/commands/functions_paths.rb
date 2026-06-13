# frozen_string_literal: true

module Arfi
  module Commands
    # Path resolution helpers for {Arfi::Commands::Functions}.
    module FunctionsPaths
      private

      # Resolve the canonical output path for a function file, respecting adapter option.
      #
      # @private
      # @param [String?] schema Schema name (optional)
      # @param [String] function_name Function name
      # @return [String] Absolute path to the function file
      def canonical_path(schema, function_name)
        root = Rails.root.join(ROOT_DIR)
        if adapter_opt.nil?
          generic_canonical_path(root, schema, function_name)
        else
          adapter_canonical_path(root, schema, function_name)
        end
      end

      # List all possible filesystem paths where a function file might exist, respecting adapter.
      #
      # @private
      # @param [String?] schema Schema name (optional)
      # @param [String] function_name Function name
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not supported
      # @return [Array<String>] List of absolute paths to check
      def function_paths(schema, function_name)
        root = Rails.root.join(ROOT_DIR)
        out = case adapter_opt
              when nil then generic_function_paths(root, function_name)
              when 'postgresql' then postgresql_function_paths(root, schema, function_name)
              when 'mysql', 'trilogy' then mysql_function_paths(root, function_name)
              else raise Arfi::Errors::AdapterNotSupported
              end
        out.uniq
      end

      # Build the canonical path for a generic (non-adapter) function.
      #
      # Generic functions can only target the 'public' schema.
      #
      # @private
      # @param [Pathname] root Project root directory (Rails.root/db/functions)
      # @param [String?] schema Schema name (must be nil or 'public')
      # @param [String] function_name Function name
      # @raise [ArgumentError] If schema is not public
      # @return [String] Absolute canonical path
      def generic_canonical_path(root, schema, function_name)
        sch = schema || DEFAULT_SCHEMA
        unless sch == DEFAULT_SCHEMA
          raise ArgumentError,
                "Generic functions can only target schema '#{DEFAULT_SCHEMA}'"
        end
        root.join(DEFAULT_SCHEMA, "#{function_name}.sql").to_s
      end

      # Build the canonical path for an adapter-specific function.
      #
      # @private
      # @param [Pathname] root Project root directory (Rails.root/db/functions)
      # @param [String?] schema Schema name (PostgreSQL only)
      # @param [String] function_name Function name
      # @raise [ArgumentError] If schema is provided for non-PostgreSQL adapter
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not supported
      # @return [String] Absolute canonical path
      def adapter_canonical_path(root, schema, function_name)
        case adapter_opt
        when 'postgresql'
          root.join('postgresql', schema || DEFAULT_SCHEMA, "#{function_name}.sql").to_s
        when 'mysql', 'trilogy'
          raise ArgumentError, 'Schema-qualified functions are only supported for PostgreSQL.' if schema

          root.join('mysql', DEFAULT_SCHEMA, "#{function_name}.sql").to_s
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end

      # List file paths to check when looking for a generic function file.
      #
      # @private
      # @param [Pathname] root Project root directory
      # @param [String] function_name Function name
      # @return [Array<String>] Ordered list of paths to check
      def generic_function_paths(root, function_name)
        [
          root.join(DEFAULT_SCHEMA, "#{function_name}.sql").to_s,
          root.join("#{function_name}.sql").to_s
        ]
      end

      # List file paths to check when looking for a PostgreSQL function file.
      #
      # @private
      # @param [Pathname] root Project root directory
      # @param [String?] schema Schema name (optional)
      # @param [String] function_name Function name
      # @return [Array<String>] Ordered list of paths to check
      def postgresql_function_paths(root, schema, function_name)
        sch = schema || DEFAULT_SCHEMA
        out = [
          root.join('postgresql', sch, "#{function_name}.sql").to_s,
          root.join('postgresql', DEFAULT_SCHEMA, "#{function_name}.sql").to_s,
          root.join(DEFAULT_SCHEMA, "#{function_name}.sql").to_s,
          root.join("#{function_name}.sql").to_s
        ]
        out.insert(2, root.join('postgresql', "#{function_name}.sql").to_s) if sch == DEFAULT_SCHEMA
        out
      end

      # List file paths to check when looking for a MySQL/Trilogy function file.
      #
      # @private
      # @param [Pathname] root Project root directory
      # @param [String] function_name Function name
      # @return [Array<String>] Ordered list of paths to check
      def mysql_function_paths(root, function_name)
        [
          root.join('mysql', DEFAULT_SCHEMA, "#{function_name}.sql").to_s,
          root.join('mysql', "#{function_name}.sql").to_s,
          root.join(DEFAULT_SCHEMA, "#{function_name}.sql").to_s,
          root.join("#{function_name}.sql").to_s
        ]
      end
    end
  end
end
