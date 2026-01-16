# frozen_string_literal: true

require 'thor'
require 'rails'
require 'fileutils'
require 'json'

module Arfi
  module Commands
    class Functions < Thor
      ADAPTERS = %i[postgresql mysql trilogy].freeze
      ROOT_DIR = 'db/functions'
      DEFAULT_SCHEMA = 'public'

      IDENT = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.freeze

      default_task :list

      # UX aliases
      map %w[ls] => :list
      map %w[rm delete del] => :destroy
      map %w[new add] => :create

      # steep:ignore:start
      desc(
        'create FUNCTION_NAME [--schema=schema --template=template_file --adapter=adapter --force]',
        "Create (or overwrite with --force) a SQL function file.\n  " \
        "Generic public:      db/functions/public/<function>.sql\n  " \
        "PostgreSQL public:   db/functions/postgresql/public/<function>.sql\n  " \
        "PostgreSQL schema:   db/functions/postgresql/<schema>/<function>.sql\n" \
        "Schema can be passed as 'schema.function' or via --schema (PostgreSQL only)."
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.function')."
      option :template, type: :string, banner: 'template_file',
                        desc: 'Path to the template file. See README.md for details.'
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :force, type: :boolean, default: false,
                     desc: 'Overwrite existing function file if it already exists.'
      # steep:ignore:end
      def create(function_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, fn = parse_function_ref(function_ref)
        validate_identifiers!(schema, fn)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        content = build_sql_function(schema, fn, original_ref: function_ref)
        write_file(schema, fn, content)
      end

      # steep:ignore:start
      desc(
        'destroy FUNCTION_NAME [--schema=schema --adapter=adapter]',
        'Delete a SQL function file (supports both new and legacy locations).'
      )
      option :schema, type: :string, banner: 'schema',
                      desc: "PostgreSQL schema name (alternative to 'schema.function')."
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      # steep:ignore:end
      def destroy(function_ref)
        validate_schema_format!
        validate_adapter_option!

        schema, fn = parse_function_ref(function_ref)
        validate_identifiers!(schema, fn)

        ensure_dirs!(adapter: adapter_opt, schema: schema)

        candidates = function_paths(schema, fn)
        path = candidates.find { |p| File.exist?(p) }

        unless path
          puts "Not found. Looked in:\n  - " + candidates.map { rel(_1) }.join("\n  - ")
          return
        end

        FileUtils.rm(path)
        puts "Deleted: #{rel(path)}"
      end

      # steep:ignore:start
      desc(
        'list [--adapter=adapter] [--format=table|paths|json] [--all]',
        "List SQL function files ARFI would load for the chosen adapter.\n" \
        "Default: inferred adapter from Rails config. Default output: table.\n" \
        '--all shows shadowed/overridden candidates too.'
      )
      option :adapter, type: :string,
                       desc: "Specify database adapter. Available adapters: #{ADAPTERS.join(', ')}",
                       banner: 'adapter'
      option :format, type: :string, default: 'table',
                      desc: 'Output format: table, paths, json'
      option :all, type: :boolean, default: false,
                   desc: 'Show all candidates (including overridden ones), not just the effective set.'
      # steep:ignore:end
      def list
        validate_schema_format!
        validate_adapter_option!

        adapter = adapter_opt || infer_adapter_from_config
        raise ArgumentError, 'Could not infer adapter. Pass --adapter=[postgresql|mysql|trilogy].' unless adapter

        rows = resolve_functions_for(adapter: adapter)

        case options[:format].to_s # steep:ignore NoMethod
        when 'paths'
          rows.each { puts rel(_1[:path]) }
        when 'json'
          puts JSON.pretty_generate(rows.map { |r| r.merge(path: rel(r[:path])) })
        else
          print_table(rows)
        end
      end

      private

      def validate_schema_format!
        fmt =
          if defined?(Rails) && Rails.application
            Rails.application.config.active_record.schema_format
          elsif defined?(ActiveRecord::Base) && ActiveRecord::Base.respond_to?(:schema_format)
            ActiveRecord::Base.schema_format
          end

        raise Arfi::Errors::InvalidSchemaFormat unless fmt == :ruby
      end

      def validate_adapter_option!
        return if adapter_opt.nil?
        raise Arfi::Errors::AdapterNotSupported unless ADAPTERS.include?(adapter_opt.to_sym)
      end

      # Accept:
      # - "my_fn"
      # - "public.my_fn"
      # - "audit.my_fn"
      # and/or --schema=audit + "my_fn"
      def parse_function_ref(ref)
        raise ArgumentError, "Invalid function name: #{ref.inspect}" unless ref.is_a?(String)

        sep = [File::SEPARATOR, File::ALT_SEPARATOR].compact
        bad = ref.empty? || ref.include?('..') || sep.any? { |s| ref.include?(s) }
        raise ArgumentError, "Invalid function name: #{ref.inspect}" if bad

        parsed_schema, parsed_fn = ref.split('.', 2)
        if parsed_fn.nil?
          parsed_fn = parsed_schema
          parsed_schema = nil
        end

        opt_schema = schema_opt
        if opt_schema && parsed_schema
          raise ArgumentError, "Schema specified twice (both 'schema.fn' and --schema). Pick one."
        end

        schema = opt_schema || parsed_schema
        [schema, parsed_fn]
      end

      def schema_opt
        # steep:ignore:start
        options[:schema]&.to_s
        # steep:ignore:end
      end

      def validate_identifiers!(schema, fn)
        raise ArgumentError, "Invalid function name: #{fn.inspect}" unless IDENT.match?(fn)
        return if schema.nil?

        raise ArgumentError, "Invalid schema name: #{schema.inspect}" unless IDENT.match?(schema)
        return unless adapter_opt && adapter_opt != 'postgresql'

        raise ArgumentError, 'Schema-qualified functions are only supported for PostgreSQL (adapter=postgresql).'
      end

      def ensure_dirs!(adapter:, schema:)
        root = Rails.root.join(ROOT_DIR)

        # Require initialization via `arfi init` (or `arfi project`)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        # Explicit generic public
        FileUtils.mkdir_p(root.join(DEFAULT_SCHEMA))

        return if adapter.nil?

        adapter_root = root.join(adapter)
        FileUtils.mkdir_p(adapter_root)

        # Explicit adapter public
        FileUtils.mkdir_p(adapter_root.join(DEFAULT_SCHEMA))

        return unless adapter == 'postgresql'

        sch = schema || DEFAULT_SCHEMA
        FileUtils.mkdir_p(adapter_root.join(sch))
      end

      def build_sql_function(schema, fn, original_ref:)
        return build_from_file(schema, fn, original_ref: original_ref) if options[:template] # steep:ignore NoMethod

        adapter = adapter_opt

        # Default/postgresql skeleton (including generic mode)
        if adapter.nil? || adapter == 'postgresql'
          sch = schema || DEFAULT_SCHEMA
          qualified = "#{sch}.#{fn}"

          return <<~SQL
            CREATE OR REPLACE FUNCTION #{qualified}() RETURNS TEXT[]
                LANGUAGE SQL
                IMMUTABLE AS
            $$
                -- Function body here
            $$
          SQL
        end

        case adapter
        when 'mysql', 'trilogy'
          <<~SQL
            -- MySQL note: you may need to DROP FUNCTION IF EXISTS #{fn};
            -- and ensure your connection allows multi-statements if you include both.
            CREATE FUNCTION #{fn} ()
            RETURNS return_type
            BEGIN
              -- Function body here
            END;
          SQL
        else
          raise "Unknown adapter: #{adapter}. Supported adapters: #{ADAPTERS.join(', ')}"
        end
      end

      # Template vars:
      # - function_name / index_name: function name only
      # - schema_name: postgres schema (defaults to public), else nil
      # - qualified_name: "schema.fn" for postgres, else fn
      def build_from_file(schema, fn, original_ref:)
        adapter = adapter_opt
        schema_name = adapter.nil? || adapter == 'postgresql' ? (schema || DEFAULT_SCHEMA) : nil
        qualified_name = schema_name ? "#{schema_name}.#{fn}" : fn

        tpl = File.read(options[:template]) # steep:ignore NoMethod

        # steep:ignore:start
        RubyVM::InstructionSequence.compile(<<~RUBY).eval
          index_name     = #{fn.inspect}
          function_name  = #{fn.inspect}
          schema_name    = #{schema_name.inspect}
          qualified_name = #{qualified_name.inspect}
          original_ref   = #{original_ref.inspect}
          #{tpl}
        RUBY
        # steep:ignore:end
      end

      def write_file(schema, fn, content)
        path = canonical_path(schema, fn)

        if File.exist?(path) && !options[:force] # steep:ignore NoMethod
          puts "Already exists: #{rel(path)} (use --force to overwrite)"
          return
        end

        File.write(path, content.to_s)
        puts "Created: #{rel(path)}"
      end

      def canonical_path(schema, fn)
        root = Rails.root.join(ROOT_DIR)
        adapter = adapter_opt

        if adapter.nil?
          sch = schema || DEFAULT_SCHEMA
          unless sch == DEFAULT_SCHEMA
            raise ArgumentError,
                  "Generic functions can only target schema '#{DEFAULT_SCHEMA}'"
          end

          return root.join(DEFAULT_SCHEMA, "#{fn}.sql").to_s
        end

        case adapter
        when 'postgresql'
          sch = schema || DEFAULT_SCHEMA
          root.join('postgresql', sch, "#{fn}.sql").to_s
        when 'mysql', 'trilogy'
          raise ArgumentError, 'Schema-qualified functions are only supported for PostgreSQL.' if schema

          root.join('mysql', DEFAULT_SCHEMA, "#{fn}.sql").to_s
        else
          raise Arfi::Errors::AdapterNotSupported
        end
      end

      # For destroy/migration support: include legacy aliases too
      def function_paths(schema, fn)
        root = Rails.root.join(ROOT_DIR)
        adapter = adapter_opt

        out = []

        if adapter.nil?
          out << root.join(DEFAULT_SCHEMA, "#{fn}.sql").to_s
          out << root.join("#{fn}.sql").to_s # legacy generic
          return out
        end

        case adapter
        when 'postgresql'
          sch = schema || DEFAULT_SCHEMA
          out << root.join('postgresql', sch, "#{fn}.sql").to_s
          out << root.join('postgresql', DEFAULT_SCHEMA, "#{fn}.sql").to_s
          out << root.join('postgresql', "#{fn}.sql").to_s if sch == DEFAULT_SCHEMA # legacy adapter public
          out << root.join(DEFAULT_SCHEMA, "#{fn}.sql").to_s
          out << root.join("#{fn}.sql").to_s
        when 'mysql', 'trilogy'
          out << root.join('mysql', DEFAULT_SCHEMA, "#{fn}.sql").to_s
          out << root.join('mysql', "#{fn}.sql").to_s # legacy mysql public
          out << root.join(DEFAULT_SCHEMA, "#{fn}.sql").to_s
          out << root.join("#{fn}.sql").to_s
        else
          raise Arfi::Errors::AdapterNotSupported
        end

        out.uniq
      end

      def adapter_opt
        # steep:ignore:start
        options[:adapter]&.to_s
        # steep:ignore:end
      end

      def infer_adapter_from_config
        # Try to avoid connecting to DB: read Rails configs
        cfgs =
          if ActiveRecord::Base.respond_to?(:configurations) && ActiveRecord::Base.configurations
            ActiveRecord::Base.configurations.configurations.select { _1.env_name == Rails.env } # steep:ignore NoMethod
          else
            []
          end

        cfg = cfgs.find { _1.name == 'primary' } || cfgs.first
        h = cfg&.configuration_hash

        adapter = h && (h[:adapter] || h['adapter'])
        adapter&.to_s
      rescue StandardError
        nil
      end

      # Priority (higher wins), same spirit as the loader I suggested earlier:
      #  10: adapter explicit schema dir (postgresql/<schema>/fn.sql)
      #   9: adapter explicit public dir (postgresql/public/fn.sql, mysql/public/fn.sql)
      #   8: adapter legacy public       (postgresql/fn.sql, mysql/fn.sql)
      #   2: generic explicit public     (public/fn.sql)
      #   1: generic legacy public       (fn.sql)
      def resolve_functions_for(adapter:)
        root = Rails.root.join(ROOT_DIR)
        raise Arfi::Errors::NoFunctionsDir unless root.directory?

        candidates = []

        # generic (public)
        candidates.concat collect_candidates(glob: root.join('*.sql'), schema: DEFAULT_SCHEMA, source: 'generic',
                                             origin: 'legacy', priority: 1)
        candidates.concat collect_candidates(glob: root.join(DEFAULT_SCHEMA, '*.sql'), schema: DEFAULT_SCHEMA,
                                             source: 'generic', origin: 'explicit', priority: 2)

        adapter_root = root.join(adapter)
        if adapter_root.directory?
          # adapter public
          candidates.concat collect_candidates(glob: adapter_root.join('*.sql'), schema: DEFAULT_SCHEMA,
                                               source: adapter, origin: 'legacy', priority: 8)
          candidates.concat collect_candidates(glob: adapter_root.join(DEFAULT_SCHEMA, '*.sql'),
                                               schema: DEFAULT_SCHEMA, source: adapter, origin: 'explicit', priority: 9)

          # adapter schema dirs (postgresql only)
          if adapter == 'postgresql'
            Dir.children(adapter_root).sort.each do |child|
              next if child.start_with?('_')
              next if child == DEFAULT_SCHEMA

              dir = adapter_root.join(child)
              next unless dir.directory?

              candidates.concat collect_candidates(glob: dir.join('*.sql'), schema: child, source: adapter,
                                                   origin: 'explicit', priority: 10)
            end
          end
        end

        # Group by identity key = schema + function name (basename)
        by_key = Hash.new { |h, k| h[k] = [] }
        candidates.each do |c|
          by_key[c[:key]] << c
        end

        # Sort within each key by priority
        by_key.each_value { |arr| arr.sort_by! { |c| c[:priority] } }

        rows = []
        by_key.keys.sort.each do |key|
          arr = by_key[key]
          chosen = arr.max_by { |c| c[:priority] }
          shadowed = (arr - [chosen])

          if options[:all] # steep:ignore NoMethod
            # show all candidates
            arr.sort_by { |c| [-c[:priority], c[:schema], c[:function]] }.each do |c|
              rows << c.merge(chosen: (c == chosen), shadowed_by: (c == chosen ? nil : rel(chosen[:path])))
            end
          else
            rows << chosen.merge(chosen: true, shadowed: shadowed.map { rel(_1[:path]) })
          end
        end

        rows
      end

      def collect_candidates(glob:, schema:, source:, origin:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          fn = File.basename(path, '.sql')
          {
            key: "#{schema}/#{base}",
            schema: schema,
            function: fn,
            source: source,     # "generic" | "postgresql" | "mysql" | "trilogy"
            origin: origin,     # "explicit" | "legacy"
            priority: priority,
            path: path
          }
        end
      end

      def print_table(rows)
        # rows may include extra fields depending on --all
        cols =
          if options[:all] # steep:ignore NoMethod
            %w[chosen schema function source origin priority path shadowed_by]
          else
            %w[schema function source origin priority path shadowed]
          end

        # stringify
        table = rows.map do |r|
          r = r.dup
          r[:path] = rel(r[:path])
          r[:chosen] = r[:chosen] ? 'yes' : 'no' if r.key?(:chosen)
          r[:shadowed] = (r[:shadowed] || []).join(', ') if r.key?(:shadowed)
          r
        end

        widths = {}
        cols.each do |c|
          widths[c] = ([c.length] + table.map { |r| r[c.to_sym].to_s.length }).max
        end

        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')

        table.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      def rel(path)
        root = Rails.root.to_s
        p = path.to_s
        p.start_with?(root) ? p.sub(root + File::SEPARATOR, '') : p
      end
    end
  end
end
