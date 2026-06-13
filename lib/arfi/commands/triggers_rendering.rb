# frozen_string_literal: true

module Arfi
  module Commands
    # Table rendering helpers for {Arfi::Commands::Triggers}.
    module TriggersRendering
      private

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

      def print_table(rows)
        cols = table_columns
        table = stringify_rows(rows)
        widths = calculate_widths(cols, table)
        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')
        render_table_rows(table, cols, widths)
      end

      def table_columns
        if options[:all]
          %w[chosen schema trigger source origin priority path shadowed_by]
        else
          %w[schema trigger source origin priority path shadowed]
        end
      end

      def stringify_rows(rows)
        rows.map do |r|
          r = r.dup
          r[:path] = rel(r[:path])
          r[:chosen] = r[:chosen] ? 'yes' : 'no' if r.key?(:chosen)
          r[:shadowed] = (r[:shadowed] || []).join(', ') if r.key?(:shadowed)
          r
        end
      end

      def calculate_widths(cols, table)
        widths = {}
        cols.each do |c|
          widths[c] = ([c.length] + table.map { |r| r[c.to_sym].to_s.length }).max
        end
        widths
      end

      def render_table_rows(table, cols, widths)
        table.each do |r|
          puts cols.map { |c| r[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      def resolve_key_group(arr)
        chosen = arr.max_by { |c| c[:priority] }
        return [] unless chosen

        if options[:all]
          all_mode_rows(arr, chosen)
        else
          default_mode_row(chosen, arr)
        end
      end

      def all_mode_rows(arr, chosen)
        chosen_path = chosen[:path]
        arr.sort_by { |c| [-c[:priority], c[:schema], c[:trigger]] }.map do |c|
          c.merge(
            chosen: (c == chosen),
            shadowed_by: (c == chosen ? nil : rel(chosen_path))
          )
        end
      end

      def default_mode_row(chosen, arr)
        shadowed = (arr - [chosen])
        [chosen.merge(chosen: true, shadowed: shadowed.map { rel(_1[:path]) })]
      end
    end
  end
end
