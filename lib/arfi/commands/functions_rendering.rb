# frozen_string_literal: true

module Arfi
  module Commands
    # Table rendering helpers for {Arfi::Commands::Functions}.
    module FunctionsRendering
      private

      # Render the resolved function list in the selected format (paths, json, or table).
      #
      # @private
      # @param [Array<Hash<Symbol, Object>>] rows Resolved function rows
      # @return [void]
      def render_list(rows)
        case options[:format].to_s
        when 'paths'
          rows.each { puts rel(_1[:path]) }
        when 'json'
          puts JSON.pretty_generate(rows.map { |r| r.merge(path: rel(r[:path])) })
        else
          print_table(rows)
        end
      end

      # Print the function list as a formatted ASCII table.
      #
      # @private
      # @param [Array<Hash<Symbol, Object>>] rows Resolved function rows
      # @return [void]
      def print_table(rows)
        cols = table_columns
        table = stringify_rows(rows)
        widths = calculate_widths(cols, table)
        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')
        render_table_rows(table, cols, widths)
      end

      # Determine which columns to display based on the --all flag.
      #
      # @private
      # @return [Array<String>] List of column names
      def table_columns
        if options[:all]
          %w[chosen schema function source origin priority path shadowed_by]
        else
          %w[schema function source origin priority path shadowed]
        end
      end

      # Convert all row values to strings for display, handling special columns.
      #
      # @private
      # @param [Array<Hash<Symbol, Object>>] rows Resolved function rows
      # @return [Array<Hash<Symbol, Object>>] Rows with string values
      def stringify_rows(rows)
        rows.map do |r|
          r = r.dup
          r[:path] = rel(r[:path])
          r[:chosen] = r[:chosen] ? 'yes' : 'no' if r.key?(:chosen)
          r[:shadowed] = (r[:shadowed] || []).join(', ') if r.key?(:shadowed)
          r
        end
      end

      # Calculate the maximum display width for each column.
      #
      # @private
      # @param [Array<String>] cols Column names
      # @param [Array<Hash<Symbol, Object>>] table Stringified table rows
      # @return [Hash<String, Integer>] Column widths keyed by column name
      def calculate_widths(cols, table)
        widths = {} # steep:ignore
        cols.each do |c|
          widths[c] = ([c.length] + table.map { |r| r[c.to_sym].to_s.length }).max
        end
        widths
      end

      # Render each table row with proper column alignment.
      #
      # @private
      # @param [Array<Hash<Symbol, Object>>] table Stringified table rows
      # @param [Array<String>] cols Column names
      # @param [Hash<String, Integer>] widths Calculated column widths
      # @return [void]
      def render_table_rows(table, cols, widths)
        table.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Resolve a group of same-key candidates to the chosen one with shadowed info.
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] arr Candidates for one function key
      # @return [Array<Hash<Symbol, Object>>] Resolved row(s) for display
      def resolve_key_group(arr)
        chosen = arr.max_by { |c| c[:priority] }
        return [] unless chosen

        if options[:all]
          all_mode_rows(arr, chosen)
        else
          default_mode_row(chosen, arr)
        end
      end

      # Build display rows for --all mode (shows all candidates including overridden ones).
      #
      # @private
      # @param [Array<Arfi::Commands::candidate>] arr All candidates for one function key
      # @param [Arfi::Commands::candidate] chosen The selected (highest-priority) candidate
      # @return [Array<Hash<Symbol, Object>>] Display rows
      def all_mode_rows(arr, chosen)
        chosen_path = chosen[:path]
        arr.sort_by { |c| [-c[:priority], c[:schema], c[:function]] }.map do |c|
          c.merge(
            chosen: (c == chosen),
            shadowed_by: (c == chosen ? nil : rel(chosen_path))
          )
        end
      end

      # Build a single display row for default mode (only the chosen candidate).
      #
      # @private
      # @param [Arfi::Commands::candidate] chosen The selected (highest-priority) candidate
      # @param [Array<Arfi::Commands::candidate>] arr All candidates for one function key
      # @return [Array<Hash<Symbol, Object>>] Single display row
      def default_mode_row(chosen, arr)
        shadowed = (arr - [chosen])
        [chosen.merge(chosen: true, shadowed: shadowed.map { rel(_1[:path]) })]
      end
    end
  end
end
