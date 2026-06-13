# frozen_string_literal: true

module Arfi
  module Commands
    # Trigger file creation helpers for {Arfi::Commands::Triggers}.
    module TriggersCreation
      private

      def ensure_dirs!(adapter:, schema:)
        root = Rails.root.join(TRIGGERS_ROOT_DIR)
        raise Arfi::Errors::NoTriggersDir unless root.directory?

        FileUtils.mkdir_p(root.join(DEFAULT_SCHEMA))
        return if adapter.nil?

        adapter_root = root.join(adapter)
        FileUtils.mkdir_p(adapter_root)
        FileUtils.mkdir_p(adapter_root.join(DEFAULT_SCHEMA))
        return unless adapter == 'postgresql'

        sch = schema || DEFAULT_SCHEMA
        FileUtils.mkdir_p(adapter_root.join(sch))
      end

      def build_sql_trigger(schema, trigger_name, original_ref:)
        return build_from_file(schema, trigger_name, original_ref: original_ref) if options[:template]

        opt = adapter_opt
        if opt.nil? || opt == 'postgresql'
          build_postgresql_trigger_skeleton(schema, trigger_name)
        elsif %w[mysql trilogy].include?(opt)
          build_mysql_trigger_skeleton(trigger_name)
        else
          raise "Unknown adapter: #{opt}. Supported adapters: #{ADAPTERS.join(', ')}"
        end
      end

      def build_from_file(schema, trigger_name, original_ref:)
        schema_name = resolve_schema_name(schema)
        qualified_name = schema_name ? "#{schema_name}.#{trigger_name}" : trigger_name
        evaluate_template(trigger_name, schema_name, qualified_name, original_ref)
      end

      def write_file(schema, trigger_name, content)
        path = canonical_path(schema, trigger_name)
        if File.exist?(path) && !options[:force]
          puts "Already exists: #{rel(path)} (use --force to overwrite)"
          return
        end
        File.write(path, content.to_s)
        puts "Created: #{rel(path)}"
      end

      def remove_trigger_file(schema, trigger_name)
        candidates = trigger_paths(schema, trigger_name)
        path = candidates.find { |p| File.exist?(p) }
        unless path
          puts "Not found. Looked in:\n  - #{candidates.map { rel(_1) }.join("\n  - ")}"
          return
        end
        FileUtils.rm(path)
        puts "Deleted: #{rel(path)}"
      end

      def evaluate_template(trigger_name, schema_name, qualified_name, original_ref)
        tpl = File.read(options[:template])
        RubyVM::InstructionSequence.compile(<<~RUBY).eval
          index_name     = #{trigger_name.inspect}
          trigger_name   = #{trigger_name.inspect}
          schema_name    = #{schema_name.inspect}
          qualified_name = #{qualified_name.inspect}
          original_ref   = #{original_ref.inspect}
          #{tpl}
        RUBY
      end

      def build_postgresql_trigger_skeleton(schema, trigger_name)
        sch = schema || DEFAULT_SCHEMA
        fn_name = options[:function] || "#{trigger_name}_fn"
        note = "You will need a trigger function: arfi functions create #{fn_name} --schema #{sch}"
        "-- #{note}\n#{pg_trigger_sql(trigger_name, sch, fn_name)}"
      end

      def pg_trigger_sql(trigger_name, sch, fn_name)
        <<~SQL
          CREATE TRIGGER #{trigger_name}
              #{pg_timing} #{pg_trigger_events} ON #{sch}.#{pg_table}
              FOR EACH #{pg_for_each}
              EXECUTE FUNCTION #{sch}.#{fn_name}();
        SQL
      end

      def pg_table
        options[:table] || 'table_name'
      end

      def pg_timing
        options[:timing] || 'BEFORE'
      end

      def pg_for_each
        options[:'for-each'] || 'ROW'
      end

      def pg_trigger_events
        Array(options[:event]).then { _1.empty? ? %w[INSERT] : _1 }.map(&:upcase).join(' OR ')
      end

      def build_mysql_trigger_skeleton(trigger_name)
        table = options[:table] || 'table_name'
        timing = options[:timing] || 'BEFORE'
        event = Array(options[:event]).first || 'INSERT'
        note = '-- You may need DROP TRIGGER IF EXISTS and multi-statement connection'
        "#{note}\n#{mysql_trigger_sql(trigger_name, timing, event, table)}"
      end

      def mysql_trigger_sql(trigger_name, timing, event, table)
        <<~SQL
          CREATE TRIGGER #{trigger_name}
              #{timing} #{event.upcase} ON #{table}
              FOR EACH ROW
          BEGIN
              -- Trigger body here
          END;
        SQL
      end
    end
  end
end
