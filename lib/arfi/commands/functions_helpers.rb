# frozen_string_literal: true

module Arfi
  module Commands
    # Shared helper methods for {Arfi::Commands::Functions}.
    module FunctionsHelpers
      private

      # Validate that the Rails schema format is set to :ruby.
      #
      # @private
      # @raise [Arfi::Errors::InvalidSchemaFormat] If schema format is not :ruby
      # @return [void]
      def validate_schema_format!
        fmt =
          if defined?(Rails) && Rails.application
            Rails.application.config.active_record.schema_format
          elsif defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:schema_format)
            ActiveRecord::Base.schema_format
          end
        raise Arfi::Errors::InvalidSchemaFormat unless fmt == :ruby
      end

      # Validate that the --adapter option, if provided, is one of the supported adapters.
      #
      # @private
      # @raise [Arfi::Errors::AdapterNotSupported] If adapter is not in the supported list
      # @return [void]
      def validate_adapter_option!
        opt = adapter_opt
        return if opt.nil?
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.map(&:to_s).include?(opt)
      end

      # Parse a function reference into an optional schema and function name.
      #
      # Accepts 'schema.function_name' or just 'function_name' form.
      #
      # @private
      # @param [String] ref Function reference string
      # @return [[ ::String?, ::String ]] Array of [schema, function_name]
      def parse_function_ref(ref)
        validate_function_ref!(ref)
        parsed_schema, parsed_fn = ref.split('.', 2)
        if parsed_fn.nil?
          parsed_fn = parsed_schema
          parsed_schema = nil
        end
        check_schema_conflict!(parsed_schema)
        schema = schema_opt || parsed_schema
        [schema, parsed_fn || '']
      end

      # Validate that schema and function name match the allowed identifier pattern.
      #
      # Schema-qualified functions are only allowed for PostgreSQL adapter.
      #
      # @private
      # @param [String?] schema Schema name to validate (optional)
      # @param [String] function_name Function name to validate
      # @raise [ArgumentError] If identifiers are invalid
      # @return [void]
      def validate_identifiers!(schema, function_name)
        raise ArgumentError, "Invalid function name: #{function_name.inspect}" unless IDENT.match?(function_name)
        return if schema.nil?
        raise ArgumentError, "Invalid schema name: #{schema.inspect}" unless IDENT.match?(schema)
        return unless adapter_opt && adapter_opt != 'postgresql'

        raise ArgumentError, 'Schema-qualified functions are only supported for PostgreSQL (adapter=postgresql).'
      end

      # Validate that a function reference is a non-empty string without path separators.
      #
      # @private
      # @param [String] ref Function reference string
      # @raise [ArgumentError] If reference is invalid
      # @return [void]
      def validate_function_ref!(ref)
        raise ArgumentError, "Invalid function name: #{ref.inspect}" unless ref.is_a?(String)

        sep = [File::SEPARATOR, File::ALT_SEPARATOR].compact
        bad = ref.empty? || ref.include?('..') || sep.any? { |s| ref.include?(s) }
        raise ArgumentError, "Invalid function name: #{ref.inspect}" if bad
      end

      # Raise if the schema is specified both inline and via the --schema option.
      #
      # @private
      # @param [String?] parsed_schema Schema parsed from 'schema.function' form
      # @raise [ArgumentError] If schema is specified twice
      # @return [void]
      def check_schema_conflict!(parsed_schema)
        return unless schema_opt && parsed_schema

        raise ArgumentError, "Schema specified twice (both 'schema.fn' and --schema). Pick one."
      end

      # Resolve the effective schema name, defaulting to 'public' for PostgreSQL/generic.
      #
      # @private
      # @param [String?] schema User-provided schema name (optional)
      # @return [String?] Resolved schema name or nil for MySQL/Trilogy
      def resolve_schema_name(schema)
        adapter = adapter_opt
        adapter.nil? || adapter == 'postgresql' ? (schema || DEFAULT_SCHEMA) : nil
      end

      # Resolve the effective adapter from CLI option or Rails DB config.
      #
      # @private
      # @raise [ArgumentError] If adapter cannot be inferred
      # @return [String] Resolved adapter name
      def resolve_adapter
        adapter_opt || infer_adapter_from_config || raise(
          ArgumentError,
          'Could not infer adapter. Pass --adapter=[postgresql|mysql|trilogy].'
        )
      end

      # Resolve the effective list of function files for a given adapter.
      #
      # @private
      # @param [String] adapter Adapter name (postgresql, mysql, trilogy)
      # @raise [Arfi::Errors::NoFunctionsDir] If db/functions directory doesn't exist
      # @return [Array<Hash<Symbol, Object>>] Resolved function rows
      def resolve_functions_for(adapter:)
        root = Rails.root.join(ROOT_DIR)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        candidates = collect_all_candidates(root, adapter)
        by_key = group_candidates_by_key(candidates)
        build_resolved_rows(by_key)
      end

      # Read the --adapter option value from CLI options.
      #
      # @private
      # @return [String?] Adapter name or nil if not provided
      def adapter_opt
        options[:adapter]&.to_s
      end

      # Infer the database adapter from the Rails primary DB configuration.
      #
      # @private
      # @raise [StandardError]
      # @return [String?] Adapter name, or nil if inference fails
      # @return [nil] if StandardError
      def infer_adapter_from_config
        cfg = primary_db_config
        h = cfg&.configuration_hash
        adapter = h && (h[:adapter] || h['adapter'])
        adapter&.to_s
      rescue StandardError
        nil
      end

      # Read the --schema option value from CLI options.
      #
      # @private
      # @return [String?] Schema name or nil if not provided
      def schema_opt
        options[:schema]&.to_s
      end

      # Get the primary database configuration for the current Rails environment.
      #
      # @private
      # @return [Object] ActiveRecord database config object
      def primary_db_config
        cfgs =
          if ActiveRecord::Base.respond_to?(:configurations) && ActiveRecord::Base.configurations
            ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env }
          else
            [] # steep:ignore
          end
        cfgs.find { _1.name == 'primary' } || cfgs.first
      end
    end
  end
end
