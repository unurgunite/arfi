# frozen_string_literal: true

module Arfi
  module Commands
    # Function file creation helpers for {Arfi::Commands::Functions}.
    module FunctionsCreation
      private

      # Method documentation.
      #
      # @private
      # @param [String?] adapter Param documentation.
      # @param [String?] schema Param documentation.
      # @raise [Arfi::Errors::NoFunctionsDir]
      # @return [void]
      def ensure_dirs!(adapter:, schema:)
        root = Rails.root.join(ROOT_DIR)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        FileUtils.mkdir_p(root.join(DEFAULT_SCHEMA))
        return if adapter.nil?

        adapter_root = root.join(adapter)
        FileUtils.mkdir_p(adapter_root)
        FileUtils.mkdir_p(adapter_root.join(DEFAULT_SCHEMA))
        return unless adapter == 'postgresql'

        sch = schema || DEFAULT_SCHEMA
        FileUtils.mkdir_p(adapter_root.join(sch))
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] function_name Param documentation.
      # @param [String] original_ref Param documentation.
      # @raise [StandardError]
      # @return [String]
      def build_sql_function(schema, function_name, original_ref:)
        return build_from_file(schema, function_name, original_ref: original_ref) if options[:template]

        opt = adapter_opt
        if opt.nil? || opt == 'postgresql'
          build_postgresql_skeleton(schema, function_name)
        elsif %w[mysql trilogy].include?(opt)
          build_mysql_skeleton(function_name)
        else
          raise "Unknown adapter: #{opt}. Supported adapters: #{ADAPTERS.join(', ')}"
        end
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] function_name Param documentation.
      # @param [String] original_ref Param documentation.
      # @return [String]
      def build_from_file(schema, function_name, original_ref:)
        schema_name = resolve_schema_name(schema)
        qualified_name = schema_name ? "#{schema_name}.#{function_name}" : function_name
        evaluate_template(function_name, schema_name, qualified_name, original_ref)
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] function_name Param documentation.
      # @param [String] content Param documentation.
      # @return [void]
      def write_file(schema, function_name, content)
        path = canonical_path(schema, function_name)
        if File.exist?(path) && !options[:force]
          puts "Already exists: #{rel(path)} (use --force to overwrite)"
          return
        end
        File.write(path, content.to_s)
        puts "Created: #{rel(path)}"
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] function_name Param documentation.
      # @return [void]
      def remove_function_file(schema, function_name)
        candidates = function_paths(schema, function_name)
        path = candidates.find { |p| File.exist?(p) }
        unless path
          puts "Not found. Looked in:\n  - #{candidates.map { rel(_1) }.join("\n  - ")}"
          return
        end
        FileUtils.rm(path)
        puts "Deleted: #{rel(path)}"
      end

      # Method documentation.
      #
      # @private
      # @param [String] function_name Param documentation.
      # @param [String?] schema_name Param documentation.
      # @param [String] qualified_name Param documentation.
      # @param [String] original_ref Param documentation.
      # @return [Object]
      def evaluate_template(function_name, schema_name, qualified_name, original_ref)
        tpl = File.read(options[:template])
        RubyVM::InstructionSequence.compile(<<~RUBY).eval # steep:ignore
          index_name     = #{function_name.inspect}
          function_name  = #{function_name.inspect}
          schema_name    = #{schema_name.inspect}
          qualified_name = #{qualified_name.inspect}
          original_ref   = #{original_ref.inspect}
          #{tpl}
        RUBY
      end

      # Method documentation.
      #
      # @private
      # @param [String?] schema Param documentation.
      # @param [String] function_name Param documentation.
      # @return [String]
      def build_postgresql_skeleton(schema, function_name)
        sch = schema || DEFAULT_SCHEMA
        qualified = "#{sch}.#{function_name}"
        <<~SQL
          CREATE OR REPLACE FUNCTION #{qualified}() RETURNS TEXT[]
              LANGUAGE SQL
              IMMUTABLE AS
          $$
              -- Function body here
          $$
        SQL
      end

      # Method documentation.
      #
      # @private
      # @param [String] function_name Param documentation.
      # @return [String]
      def build_mysql_skeleton(function_name)
        <<~SQL
          -- MySQL note: you may need to DROP FUNCTION IF EXISTS #{function_name};
          -- and ensure your connection allows multi-statements if you include both.
          CREATE FUNCTION #{function_name} ()
          RETURNS return_type
          BEGIN
            -- Function body here
          END;
        SQL
      end
    end
  end
end
