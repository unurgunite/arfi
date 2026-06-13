# frozen_string_literal: true

module Arfi
  module Commands
    # Table-rendering helpers for {Arfi::Commands::TriggersDoctor}.
    module TriggersDoctorRendering
      private

      # Render validation results in the selected output format.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def report_validate_results(results)
        case options[:format].to_s
        when 'json'
          puts JSON.pretty_generate(results.map { |result| format_validate_result(result) })
        when 'paths'
          results.each { |result| puts "#{rel(result[:file].to_s)}  #{result[:status]}" }
        else
          print_validate_table(results)
        end
      end

      # Format a validation result for JSON output.
      #
      # @private
      # @param [Hash] result
      # @return [Hash]
      def format_validate_result(result)
        { file: rel(result[:file].to_s), status: result[:status], error: result[:error] }.compact
      end

      # Print validation results as an ASCII table.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def print_validate_table(results)
        cols = %w[file status error]
        rows = build_validate_rows(results)
        widths = calculate_col_widths(cols, rows)
        print_separator(cols, widths)
        rows.each do |row|
          puts cols.map { |c| row[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Build table rows for validate results.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [Array<Hash{Symbol => String}>]
      def build_validate_rows(results)
        results.map do |result| # steep:ignore
          { file: rel(result[:file].to_s), status: result[:status], error: result[:error] || '' }
        end
      end

      # Render doctor results in the selected output format.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def report_doctor_results(results)
        case options[:format].to_s
        when 'json'
          puts JSON.pretty_generate(results)
        when 'paths'
          results.each { |result| puts "#{rel(result[:path].to_s)}  #{result[:status]}" }
        else
          print_doctor_table(results)
        end
      end

      # Print doctor results as an ASCII table with trigger, schema, table, status, path columns.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [void]
      def print_doctor_table(results)
        cols = %w[trigger schema table status path]
        rows = build_doctor_rows(results)
        widths = calculate_col_widths(cols, rows)
        print_separator(cols, widths)
        rows.each do |row|
          puts cols.map { |c| row[c.to_sym].to_s.ljust(widths[c]) }.join('  ')
        end
      end

      # Build table rows for doctor results.
      #
      # @private
      # @param [Array<Hash>] results
      # @return [Array<Hash{Symbol => String}>]
      def build_doctor_rows(results)
        results.map do |result|
          { trigger: result[:trigger], schema: result[:schema], table: result[:table],
            status: result[:status], path: rel(result[:path].to_s) }
        end
      end

      # Calculate column widths for the ASCII table.
      #
      # @private
      # @param [Array<String>] cols column names
      # @param [Array<Hash>] rows
      # @return [Hash<String, Integer>]
      def calculate_col_widths(cols, rows)
        widths = {} # steep:ignore
        cols.each do |c|
          widths[c] = ([c.length] + rows.map { |r| r[c.to_sym].to_s.length }).max
        end
        widths
      end

      # Print the table header and separator line.
      #
      # @private
      # @param [Array<String>] cols
      # @param [Hash<String, Integer>] widths
      # @return [void]
      def print_separator(cols, widths)
        puts cols.map { |c| c.ljust(widths[c]) }.join('  ')
        puts cols.map { |c| '-' * widths[c] }.join('  ')
      end
    end
  end
end
