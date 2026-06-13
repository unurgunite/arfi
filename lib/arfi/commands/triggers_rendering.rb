# frozen_string_literal: true

module Arfi
  module Commands
    # Table rendering helpers for {Arfi::Commands::Triggers}.
    module TriggersRendering
      private

      # Renders trigger list in the selected output format (paths, json, or table).
      #
      # @private
      # @param [Array<Hash<Symbol, Object>>] rows resolved trigger rows
      # @return [void]
      def render_list(rows)
        case options[:format].to_s
        when 'paths'
          rows.each { puts rel(_1[:path]) }
        when 'json'
          puts JSON.pretty_generate(rows.map { |r| r.merge(path: rel(r[:path])) })
        else
          print_table(rows) # steep:ignore
        end
      end

      # Prints a formatted table of resolved trigger rows to stdout.
      #
      # @private
      # @param [Array<Arfi::Commands::resolved_row>] rows
      # @return [void]
      def print_table(rows)
        cols = table_columns
        table = stringify_rows(rows)
        widths = calculate_widths(cols, table)
        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')
        render_table_rows(table, cols, widths)
      end

      # Returns the column headers for the table view.
      #
      # Includes extra columns when --all is set.
      #
      # @private
      # @return [Array<String>]
      def table_columns
        if options[:all]
          %w[chosen schema trigger source origin priority path shadowed_by]
        else
          %w[schema trigger source origin priority path shadowed]
        end
      end

      # Converts row values to strings for table display (path, chosen, shadowed).
      #
      # @private
      # @param [Array<Arfi::Commands::resolved_row>] rows
      # @return [Array<Arfi::Commands::resolved_row>]
      def stringify_rows(rows)
        rows.map do |r|
          r = r.dup
          r[:path] = rel(r[:path])
          r[:chosen] = r[:chosen] ? 'yes' : 'no' if r.key?(:chosen)
          r[:shadowed] = (r[:shadowed] || []).join(', ') if r.key?(:shadowed)
          r
        end
      end

      # Calculates column widths based on header and row values.
      #
      # @private
      # @param [Array<String>] cols column names
      # @param [Array<Arfi::Commands::resolved_row>] table stringified rows
      # @return [Hash<String, Integer>]
      def calculate_widths(cols, table)
        widths = {} # steep:ignore
        cols.each do |c|
          widths[c] = ([c.length] + table.map { |r| r[c.to_sym].to_s.length }).max
        end
        widths
      end

      # Prints each table row with proper column padding.
      #
      # @private
      # @param [Array<Arfi::Commands::resolved_row>] table
      # @param [Array<String>] cols
      # @param [Hash<String, Integer>] widths
      # @return [void]
      def render_table_rows(table, cols, widths)
        table.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Resolves a group of candidates (same key) into display rows.
      #
      # Chooses the highest-priority candidate; shows shadowed candidates with --all.
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] arr candidates for one key
      # @return [Array<Hash<Symbol, Object>>]
      def resolve_key_group(arr)
        chosen = arr.max_by { |c| c[:priority] }
        return [] unless chosen

        if options[:all]
          all_mode_rows(arr, chosen)
        else
          default_mode_row(chosen, arr)
        end
      end

      # Builds display rows for --all mode, including shadowed candidates.
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] arr
      # @param [Arfi::Commands::candidate] chosen highest-priority candidate
      # @return [Array<Hash<Symbol, Object>>]
      def all_mode_rows(arr, chosen) # steep:ignore
        chosen_path = chosen[:path]
        arr.sort_by { |c| [-c[:priority], c[:schema], c[:trigger]] }.map do |c| # steep:ignore
          c.merge(
            chosen: (c == chosen),
            shadowed_by: (c == chosen ? nil : rel(chosen_path))
          )
        end
      end

      # Builds a single display row for default mode with shadowed paths list.
      #
      # @private
      # @param [Arfi::Commands::candidate] chosen
      # @param [Array<Arfi::Commands::candidate>] arr all candidates for the key
      # @return [Array<Hash<Symbol, Object>>]
      def default_mode_row(chosen, arr) # steep:ignore
        shadowed = (arr - [chosen])
        [chosen.merge(chosen: true, shadowed: shadowed.map { rel(_1[:path]) })]
      end
    end
  end
end
