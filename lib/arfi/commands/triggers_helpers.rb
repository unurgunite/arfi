# frozen_string_literal: true

module Arfi
  module Commands
    # Shared helper methods for {Arfi::Commands::Triggers}.
    module TriggersHelpers
      private

      # Method documentation.
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

      # Method documentation.
      #
      # @private
      # @raise [Arfi::Errors::AdapterNotSupported]
      # @return [void]
      def validate_adapter_option!
        opt = adapter_opt
        return if opt.nil?
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.map(&:to_s).include?(opt)
      end

      # Method documentation.
      #
      # @private
      # @param [String] ref Param documentation.
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

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] trigger_name Param documentation.
      # @raise [ArgumentError]
      # @return [void]
      def validate_identifiers!(schema, trigger_name)
        raise ArgumentError, "Invalid trigger name: #{trigger_name.inspect}" unless IDENT.match?(trigger_name)
        return if schema.nil?
        raise ArgumentError, "Invalid schema name: #{schema.inspect}" unless IDENT.match?(schema)
        return unless adapter_opt && adapter_opt != 'postgresql'

        raise ArgumentError, 'Schema-qualified triggers are only supported for PostgreSQL.'
      end

      # Method documentation.
      #
      # @private
      # @param [String] ref Param documentation.
      # @raise [ArgumentError]
      # @return [void]
      def validate_trigger_ref!(ref)
        raise ArgumentError, "Invalid trigger name: #{ref.inspect}" unless ref.is_a?(String)

        sep = [File::SEPARATOR, File::ALT_SEPARATOR].compact
        bad = ref.empty? || ref.include?('..') || sep.any? { |s| ref.include?(s) }
        raise ArgumentError, "Invalid trigger name: #{ref.inspect}" if bad
      end

      # Method documentation.
      #
      # @private
      # @param [String?] parsed_schema Param documentation.
      # @raise [ArgumentError]
      # @return [void]
      def check_schema_conflict!(parsed_schema)
        return unless schema_opt && parsed_schema

        raise ArgumentError, "Schema specified twice (both 'schema.trigger' and --schema). Pick one."
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @return [String?]
      def resolve_schema_name(schema)
        adapter = adapter_opt
        adapter.nil? || adapter == 'postgresql' ? (schema || DEFAULT_SCHEMA) : nil
      end

      # Method documentation.
      #
      # @private
      # @raise [ArgumentError]
      # @return [String]
      def resolve_adapter
        adapter_opt || infer_adapter_from_config || raise(
          ArgumentError,
          'Could not infer adapter. Pass --adapter=[postgresql|mysql|trilogy].'
        )
      end

      # Method documentation.
      #
      # @private
      # @param [String] adapter Param documentation.
      # @raise [Arfi::Errors::NoTriggersDir]
      # @return [Array<Hash<Symbol, Object>>]
      def resolve_triggers_for(adapter:)
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        raise Arfi::Errors::NoTriggersDir unless root.directory?

        candidates = collect_all_candidates(root, adapter)
        by_key = group_candidates_by_key(candidates)
        build_resolved_rows(by_key)
      end

      # Method documentation.
      #
      # @private
      # @return [String?]
      def adapter_opt
        options[:adapter]&.to_s
      end

      # Method documentation.
      #
      # @private
      # @return [String?]
      def schema_opt
        options[:schema]&.to_s
      end

      # Method documentation.
      #
      # @private
      # @raise [StandardError]
      # @return [String?]
      # @return [nil] if StandardError
      def infer_adapter_from_config
        cfg = primary_db_config
        h = cfg&.configuration_hash
        adapter = h && (h[:adapter] || h['adapter'])
        adapter&.to_s
      rescue StandardError
        nil
      end

      # Method documentation.
      #
      # @private
      # @return [Object]
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
