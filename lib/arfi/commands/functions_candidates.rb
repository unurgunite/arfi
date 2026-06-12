# frozen_string_literal: true

module Arfi
  module Commands
    # Candidate discovery helpers for {Arfi::Commands::Functions}.
    module FunctionsCandidates
      private

      # Method documentation.
      #
      # @private
      # @param [Pathname] root Param documentation.
      # @param [String] adapter Param documentation.
      # @return [Array<Arfi::Commands::candidate>]
      def collect_all_candidates(root, adapter)
        candidates = generic_candidates(root)
        adapter_root = root.join(adapter)
        return candidates unless adapter_root.directory?

        candidates.concat adapter_candidates(adapter_root, adapter)
        candidates.concat collect_postgresql_schema_candidates(adapter_root, adapter) if adapter == 'postgresql'
        candidates
      end

      # Method documentation.
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] candidates Param documentation.
      # @return [Hash<String, Array<Arfi::Commands::candidate>>]
      def group_candidates_by_key(candidates)
        by_key = Hash.new { |h, k| h[k] = [] } # steep:ignore
        candidates.each do |c|
          by_key[c[:key]] << c
        end
        by_key.each_value { |arr| arr.sort_by! { |c| c[:priority] } }
        by_key
      end

      # Method documentation.
      #
      # @private
      # @param [Hash<String, Array<Arfi::Commands::candidate>>] by_key Param documentation.
      # @return [Array<Hash<Symbol, Object>>]
      def build_resolved_rows(by_key)
        by_key.keys.sort.flat_map do |key|
          resolve_key_group(by_key[key])
        end.compact
      end

      # Method documentation.
      #
      # @private
      # @param [Pathname, String] path Param documentation.
      # @return [String]
      def rel(path)
        root = Rails.root.to_s
        p = path.to_s
        p.start_with?(root) ? p.sub(root + File::SEPARATOR, '') : p
      end

      # Method documentation.
      #
      # @private
      # @param [Pathname] root Param documentation.
      # @return [Array<Arfi::Commands::candidate>]
      def generic_candidates(root)
        candidates = [] # steep:ignore
        candidates.concat collect_candidates(glob: root.join('*.sql'), schema: DEFAULT_SCHEMA, source: 'generic',
                                             origin: 'legacy', priority: 1)
        candidates.concat collect_candidates(glob: root.join(DEFAULT_SCHEMA, '*.sql'), schema: DEFAULT_SCHEMA,
                                             source: 'generic', origin: 'explicit', priority: 2)
        candidates
      end

      # Method documentation.
      #
      # @private
      # @param [Pathname] adapter_root Param documentation.
      # @param [String] adapter Param documentation.
      # @return [Array<Arfi::Commands::candidate>]
      def adapter_candidates(adapter_root, adapter)
        candidates = [] # steep:ignore
        candidates.concat collect_candidates(glob: adapter_root.join('*.sql'), schema: DEFAULT_SCHEMA,
                                             source: adapter, origin: 'legacy', priority: 8)
        candidates.concat collect_candidates(glob: adapter_root.join(DEFAULT_SCHEMA, '*.sql'),
                                             schema: DEFAULT_SCHEMA, source: adapter, origin: 'explicit', priority: 9)
        candidates
      end

      # Method documentation.
      #
      # @private
      # @param [Pathname] adapter_root Param documentation.
      # @param [String] adapter Param documentation.
      # @return [Array<Arfi::Commands::candidate>]
      def collect_postgresql_schema_candidates(adapter_root, adapter)
        Dir.children(adapter_root).sort.each_with_object([]) do |child, acc|
          next if child.start_with?('_')
          next if child == DEFAULT_SCHEMA

          dir = adapter_root.join(child)
          next unless dir.directory?

          acc.concat collect_candidates(glob: dir.join('*.sql'), schema: child, source: adapter,
                                        origin: 'explicit', priority: 10)
        end
      end

      # Method documentation.
      #
      # @private
      # @param [Pathname] glob Param documentation.
      # @param [String] schema Param documentation.
      # @param [String] source Param documentation.
      # @param [String] origin Param documentation.
      # @param [Integer] priority Param documentation.
      # @return [Array<Arfi::Commands::candidate>]
      def collect_candidates(glob:, schema:, source:, origin:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          key = "#{schema}/#{base}"
          function_name = File.basename(path, '.sql')
          {
            key: key, schema: schema, function: function_name,
            source: source, origin: origin, priority: priority, path: path
          }
        end
      end
    end
  end
end
