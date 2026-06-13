# frozen_string_literal: true

module Arfi
  module Commands
    # Candidate discovery helpers for {Arfi::Commands::Triggers}.
    module TriggersCandidates
      private

      # Collects all candidate trigger files from generic and adapter-specific directories.
      #
      # @private
      # @param [Pathname] root db/triggers
      # @param [String] adapter database adapter name
      # @return [Array<Arfi::Commands::candidate>]
      def collect_all_candidates(root, adapter)
        candidates = generic_candidates(root)
        adapter_root = root.join(adapter)
        return candidates unless adapter_root.directory?

        candidates.concat adapter_candidates(adapter_root, adapter)
        candidates.concat collect_postgresql_schema_candidates(adapter_root, adapter) if adapter == 'postgresql'
        candidates
      end

      # Groups candidates by their composite key (schema/trigger_name).
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] candidates
      # @return [Hash<String, Array<Arfi::Commands::candidate>>]
      def group_candidates_by_key(candidates)
        by_key = Hash.new { |h, k| h[k] = [] } # steep:ignore
        candidates.each do |c|
          by_key[c[:key]] << c
        end
        by_key.each_value { |arr| arr.sort_by! { |c| c[:priority] } }
        by_key
      end

      # Builds the final resolved display rows from grouped candidates.
      #
      # @private
      # @param [Hash<String, Array<Arfi::Commands::candidate>>] by_key candidates grouped by key
      # @return [Array<Hash<Symbol, Object>>]
      def build_resolved_rows(by_key)
        by_key.keys.sort.flat_map do |key|
          resolve_key_group(by_key[key])
        end.compact
      end

      # Converts an absolute path to a Rails-root-relative path for display.
      #
      # @private
      # @param [Pathname, String] path
      # @return [String]
      def rel(path)
        root = Rails.root.to_s
        p = path.to_s
        p.start_with?(root) ? p.sub(root + File::SEPARATOR, '') : p
      end

      # Collects generic (no adapter) candidates from db/triggers/ and db/triggers/public/.
      #
      # @private
      # @param [Pathname] root db/triggers
      # @return [Array<Arfi::Commands::candidate>]
      def generic_candidates(root)
        candidates = [] # steep:ignore
        candidates.concat collect_candidates(glob: root.join('*.sql'), schema: DEFAULT_SCHEMA, source: 'generic',
                                             origin: 'legacy', priority: 1)
        candidates.concat collect_candidates(glob: root.join(DEFAULT_SCHEMA, '*.sql'), schema: DEFAULT_SCHEMA,
                                             source: 'generic', origin: 'explicit', priority: 2)
        candidates
      end

      # Collects adapter-specific candidates from db/triggers/<adapter>/ and db/triggers/<adapter>/public/.
      #
      # @private
      # @param [Pathname] adapter_root db/triggers/<adapter>
      # @param [String] adapter database adapter name
      # @return [Array<Arfi::Commands::candidate>]
      def adapter_candidates(adapter_root, adapter)
        candidates = [] # steep:ignore
        candidates.concat collect_candidates(glob: adapter_root.join('*.sql'), schema: DEFAULT_SCHEMA,
                                             source: adapter, origin: 'legacy', priority: 8)
        candidates.concat collect_candidates(glob: adapter_root.join(DEFAULT_SCHEMA, '*.sql'),
                                             schema: DEFAULT_SCHEMA, source: adapter, origin: 'explicit', priority: 9)
        candidates
      end

      # Collects PostgreSQL schema-specific candidates (non-public subdirectories).
      #
      # @private
      # @param [Pathname] adapter_root db/triggers/postgresql
      # @param [String] adapter "postgresql"
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

      # Collects candidate entries from a glob pattern with metadata.
      #
      # Skips files starting with underscore (disabled).
      #
      # @private
      # @param [Pathname] glob glob pattern for matching SQL files
      # @param [String] schema schema name
      # @param [String] source "generic" or adapter name
      # @param [String] origin "legacy" or "explicit"
      # @param [Integer] priority higher wins when multiple candidates exist for the same key
      # @return [Array<Arfi::Commands::candidate>]
      def collect_candidates(glob:, schema:, source:, origin:, priority:)
        Dir.glob(glob.to_s).filter_map do |path|
          base = File.basename(path)
          next if base.start_with?('_')

          key = "#{schema}/#{base}"
          trigger_name = File.basename(path, '.sql')
          {
            key: key, schema: schema, trigger: trigger_name,
            source: source, origin: origin, priority: priority, path: path
          }
        end
      end
    end
  end
end
