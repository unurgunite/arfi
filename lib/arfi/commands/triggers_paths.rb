# frozen_string_literal: true

module Arfi
  module Commands
    # Path resolution helpers for {Arfi::Commands::Triggers}.
    module TriggersPaths
      private

      def canonical_path(schema, trigger_name)
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        if adapter_opt.nil?
          generic_canonical_path(root, schema, trigger_name)
        else
          adapter_canonical_path(root, schema, trigger_name)
        end
      end

      def trigger_paths(schema, trigger_name)
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        out = case adapter_opt
              when nil then generic_trigger_paths(root, trigger_name)
              when 'postgresql' then postgresql_trigger_paths(root, schema, trigger_name)
              when 'mysql', 'trilogy' then mysql_trigger_paths(root, trigger_name)
              else raise Arfi::Errors::AdapterNotSupported
              end
        out.uniq
      end

      def generic_canonical_path(root, schema, trigger_name)
        sch = schema || DEFAULT_SCHEMA
        unless sch == DEFAULT_SCHEMA
          raise ArgumentError,
                "Generic triggers can only target schema '#{DEFAULT_SCHEMA}'"
        end
        root.join(DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s
      end

      def adapter_canonical_path(root, schema, trigger_name)
        case adapter_opt
        when 'postgresql'
          root.join('postgresql', schema || DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s
        when 'mysql', 'trilogy'
          raise ArgumentError, 'Schema-qualified triggers are only supported for PostgreSQL.' if schema

          root.join('mysql', DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end

      def generic_trigger_paths(root, trigger_name)
        [
          root.join(DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s,
          root.join("#{trigger_name}.sql").to_s
        ]
      end

      def postgresql_trigger_paths(root, schema, trigger_name)
        sch = schema || DEFAULT_SCHEMA
        out = [
          root.join('postgresql', sch, "#{trigger_name}.sql").to_s,
          root.join('postgresql', DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s,
          root.join(DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s,
          root.join("#{trigger_name}.sql").to_s
        ]
        out.insert(2, root.join('postgresql', "#{trigger_name}.sql").to_s) if sch == DEFAULT_SCHEMA
        out
      end

      def mysql_trigger_paths(root, trigger_name)
        [
          root.join('mysql', DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s,
          root.join('mysql', "#{trigger_name}.sql").to_s,
          root.join(DEFAULT_SCHEMA, "#{trigger_name}.sql").to_s,
          root.join("#{trigger_name}.sql").to_s
        ]
      end
    end
  end
end
