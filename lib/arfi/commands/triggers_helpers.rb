# frozen_string_literal: true

module Arfi
  module Commands
    # Shared helper methods for {Arfi::Commands::Triggers}.
    module TriggersHelpers
      private

      # Raises unless schema format is :ruby (ARFI requires schema.rb).
      #
      # @private
      # @raise [Arfi::Errors::InvalidSchemaFormat]
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

      # Raises unless --adapter value (if given) is in the supported list.
      #
      # @private
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def validate_adapter_option!
        opt = adapter_opt
        return if opt.nil?
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.map(&:to_s).include?(opt)
      end

      # Parses a trigger reference string into [schema, trigger_name].
      #
      # Supports "schema.name" format and/or --schema option.
      #
      # @private
      # @param [String] ref e.g. "public.my_trigger" or "my_trigger"
      # @return [[ ::String?, ::String ]]
      def parse_trigger_ref(ref)
        validate_trigger_ref!(ref)
        parsed_schema, parsed_fn = ref.split('.', 2)
        if parsed_fn.nil?
          parsed_fn = parsed_schema
          parsed_schema = nil
        end
        check_schema_conflict!(parsed_schema)
        schema = schema_opt || parsed_schema
        [schema, parsed_fn || '']
      end

      # Validates that schema and trigger names match the allowed identifier pattern.
      #
      # Also rejects schema-qualified triggers for non-PostgreSQL adapters.
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @raise [ArgumentError] if names are invalid or schema not allowed for adapter
      # @return [void]
      def validate_identifiers!(schema, trigger_name)
        raise ArgumentError, "Invalid trigger name: #{trigger_name.inspect}" unless IDENT.match?(trigger_name)
        return if schema.nil?
        raise ArgumentError, "Invalid schema name: #{schema.inspect}" unless IDENT.match?(schema)
        return unless adapter_opt && adapter_opt != 'postgresql'

        raise ArgumentError, 'Schema-qualified triggers are only supported for PostgreSQL.'
      end

      # Validates the raw trigger reference string (non-empty, no path separators).
      #
      # @private
      # @param [String] ref
      # @raise [ArgumentError] if ref is empty or contains path separators
      # @return [void]
      def validate_trigger_ref!(ref)
        raise ArgumentError, "Invalid trigger name: #{ref.inspect}" unless ref.is_a?(String)

        sep = [File::SEPARATOR, File::ALT_SEPARATOR].compact
        bad = ref.empty? || ref.include?('..') || sep.any? { |s| ref.include?(s) }
        raise ArgumentError, "Invalid trigger name: #{ref.inspect}" if bad
      end

      # Raises if schema is provided both via "schema.name" and --schema option.
      #
      # @private
      # @param [String?] parsed_schema schema extracted from the ref string
      # @raise [ArgumentError]
      # @return [void]
      def check_schema_conflict!(parsed_schema)
        return unless schema_opt && parsed_schema

        raise ArgumentError, "Schema specified twice (both 'schema.trigger' and --schema). Pick one."
      end

      # Resolves the schema name: returns schema or DEFAULT_SCHEMA for PostgreSQL/generic, nil for MySQL.
      #
      # @private
      # @param [String?] schema
      # @return [String?]
      def resolve_schema_name(schema)
        adapter = adapter_opt
        adapter.nil? || adapter == 'postgresql' ? (schema || DEFAULT_SCHEMA) : nil
      end

      # Resolves the database adapter: --adapter option, inferred from Rails config, or raises.
      #
      # @private
      # @raise [ArgumentError] if adapter cannot be determined
      # @return [String]
      def resolve_adapter
        adapter_opt || infer_adapter_from_config || raise(
          ArgumentError,
          'Could not infer adapter. Pass --adapter=[postgresql|mysql|trilogy].'
        )
      end

      # Collects, groups, and resolves all candidate SQL files for the given adapter.
      #
      # @private
      # @param [String] adapter database adapter name
      # @raise [Arfi::Errors::NoTriggersDir] if db/triggers does not exist
      # @return [Array<Hash<Symbol, Object>>] resolved display rows
      def resolve_triggers_for(adapter:)
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        raise Arfi::Errors::NoTriggersDir unless root.directory?

        candidates = collect_all_candidates(root, adapter)
        by_key = group_candidates_by_key(candidates)
        build_resolved_rows(by_key)
      end

      # Returns the --adapter CLI option value as a string, or nil.
      #
      # @private
      # @return [String?]
      def adapter_opt
        options[:adapter]&.to_s
      end

      # Returns the --schema CLI option value as a string, or nil.
      #
      # @private
      # @return [String?]
      def schema_opt
        options[:schema]&.to_s
      end

      # Infers the database adapter name from the primary Rails database config.
      #
      # @private
      # @raise [StandardError] if config lookup fails
      # @return [String?]
      def infer_adapter_from_config
        cfg = primary_db_config
        h = cfg&.configuration_hash
        adapter = h && (h[:adapter] || h['adapter'])
        adapter&.to_s
      rescue StandardError
        nil
      end

      # Returns the primary (or first) database config for the current Rails env.
      #
      # @private
      # @return [Object] ActiveRecord::DatabaseConfigurations::HashConfig or similar
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
