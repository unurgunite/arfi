# frozen_string_literal: true

module Arfi
  module Commands
    # Trigger file creation helpers for {Arfi::Commands::Triggers}.
    module TriggersCreation
      private

      # Creates missing subdirectories under db/triggers for the given adapter and schema.
      #
      # @private
      # @param [String?] adapter e.g. "postgresql", "mysql", or nil for generic
      # @param [String?] schema e.g. "public", "audit", or nil
      # @raise [Arfi::Errors::NoTriggersDir] if db/triggers does not exist
      # @return [void]
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

      # Builds the SQL CREATE TRIGGER statement for the given adapter.
      #
      # Delegates to {#build_from_file} when a --template is given, otherwise
      # dispatches to the adapter-specific skeleton builder.
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @param [String] original_ref raw CLI argument (for error messages)
      # @raise [StandardError] if adapter is unknown
      # @return [String] complete SQL for the trigger
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

      # Renders trigger SQL from an ERB template file.
      #
      # Resolves the schema name, then evaluates the template via {#evaluate_template}.
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @param [String] original_ref raw CLI argument (for error messages)
      # @return [String]
      def build_from_file(schema, trigger_name, original_ref:)
        schema_name = resolve_schema_name(schema)
        qualified_name = schema_name ? "#{schema_name}.#{trigger_name}" : trigger_name
        evaluate_template(trigger_name, schema_name, qualified_name, original_ref)
      end

      # Writes a trigger SQL file to disk unless it exists (no --force).
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @param [String] content the SQL content to write
      # @return [void]
      def write_file(schema, trigger_name, content)
        path = canonical_path(schema, trigger_name)
        if File.exist?(path) && !options[:force]
          puts "Already exists: #{rel(path)} (use --force to overwrite)"
          return
        end
        File.write(path, content.to_s)
        puts "Created: #{rel(path)}"
      end

      # Removes a trigger SQL file from the appropriate adapter/generic directory.
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @return [void]
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

      # Evaluates an ERB template file as an inline Ruby string with binding.
      #
      # Reads --template path, wraps it in a heredoc, compiles with RubyVM, and evals.
      # The template has access to: trigger_name, schema_name, qualified_name, original_ref.
      #
      # @private
      # @param [String] trigger_name
      # @param [String?] schema_name resolved schema or nil
      # @param [String] qualified_name schema.trigger_name or just trigger_name
      # @param [String] original_ref raw CLI argument (for error messages)
      # @raise [StandardError] if template file is missing or eval fails
      # @return [String] rendered SQL
      def evaluate_template(trigger_name, schema_name, qualified_name, original_ref)
        tpl = File.read(options[:template])
        RubyVM::InstructionSequence.compile(<<~RUBY).eval # steep:ignore
          index_name     = #{trigger_name.inspect}
          trigger_name   = #{trigger_name.inspect}
          schema_name    = #{schema_name.inspect}
          qualified_name = #{qualified_name.inspect}
          original_ref   = #{original_ref.inspect}
          #{tpl}
        RUBY
      end

      # Generates a PostgreSQL skeleton CREATE TRIGGER with EXECUTE FUNCTION.
      #
      # Uses CLI options: --table, --event (repeatable), --timing, --for-each, --function.
      #
      # @private
      # @param [String?] schema
      # @param [String] trigger_name
      # @return [String] the generated SQL
      def build_postgresql_trigger_skeleton(schema, trigger_name)
        sch = schema || DEFAULT_SCHEMA
        fn_name = options[:function] || "#{trigger_name}_fn"
        note = "You will need a trigger function: arfi functions create #{fn_name} --schema #{sch}"
        "-- #{note}\n#{pg_trigger_sql(trigger_name, sch, fn_name)}"
      end

      # Formats the CREATE TRIGGER SQL for PostgreSQL with schema-qualified names.
      #
      # @private
      # @param [String] trigger_name
      # @param [String] sch schema name
      # @param [String] fn_name function name
      # @return [String] the formatted SQL
      def pg_trigger_sql(trigger_name, sch, fn_name)
        <<~SQL
          CREATE TRIGGER #{trigger_name}
              #{pg_timing} #{pg_trigger_events} ON #{sch}.#{pg_table}
              FOR EACH #{pg_for_each}
              EXECUTE FUNCTION #{sch}.#{fn_name}();
        SQL
      end

      # Returns the table name from --table option or a placeholder.
      #
      # @private
      # @return [String]
      def pg_table
        options[:table] || 'table_name'
      end

      # Returns the trigger timing from --timing option or defaults to BEFORE.
      #
      # @private
      # @return [String]
      def pg_timing
        options[:timing] || 'BEFORE'
      end

      # Returns FOR EACH scope from --for-each option or defaults to ROW.
      #
      # @private
      # @return [String]
      def pg_for_each
        options[:'for-each'] || 'ROW'
      end

      # Builds the event clause (INSERT, UPDATE, DELETE) from --event options.
      #
      # @private
      # @return [String] e.g. "INSERT OR UPDATE OR DELETE"
      def pg_trigger_events
        Array(options[:event]).then { _1.empty? ? %w[INSERT] : _1 }.map(&:upcase).join(' OR ')
      end

      # Generates a MySQL skeleton CREATE TRIGGER with BEGIN ... END body.
      #
      # Uses CLI options: --table, --event (first only -- MySQL supports one event),
      # --timing, --for-each.
      #
      # @private
      # @param [String] trigger_name
      # @return [String] the generated SQL
      def build_mysql_trigger_skeleton(trigger_name)
        table = options[:table] || 'table_name'
        timing = options[:timing] || 'BEFORE'
        event = Array(options[:event]).first || 'INSERT'
        note = '-- You may need DROP TRIGGER IF EXISTS and multi-statement connection'
        "#{note}\n#{mysql_trigger_sql(trigger_name, timing, event, table)}"
      end

      # Formats the CREATE TRIGGER SQL for MySQL with the given parameters.
      #
      # @private
      # @param [String] trigger_name
      # @param [String] timing BEFORE or AFTER
      # @param [String] event INSERT, UPDATE, or DELETE
      # @param [String] table
      # @return [String] the formatted SQL
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
