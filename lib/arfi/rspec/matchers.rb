# frozen_string_literal: true

if defined?(RSpec)
  RSpec::Matchers.define :have_arfi_function do
    match do |actual|
      ActiveRecord::Base.function_exists?(actual)
    end
  end

  RSpec::Matchers.define :have_arfi_trigger do
    chain :on_table do |table_name|
      @table_name = table_name
    end

    match do |actual|
      raise ArgumentError, 'use .on_table(:table_name) chain' if @table_name.nil?

      ActiveRecord::Base.trigger_exists?(@table_name, actual)
    end
  end
end
