# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::Functions do
  describe 'show' do
    it 'displays the SQL source of a function from the database', :pgsql do # rubocop:disable RSpec/ExampleLength
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE OR REPLACE FUNCTION public.show_test_fn()
        RETURNS INT LANGUAGE SQL AS $$ SELECT 42; $$;
      SQL

      expect { described_class.start(%w[show show_test_fn]) }
        .to output(/SELECT 42/).to_stdout
    end

    it 'includes the full function definition in the output', :pgsql do # rubocop:disable RSpec/ExampleLength
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE OR REPLACE FUNCTION public.show_detail_fn()
        RETURNS INT LANGUAGE SQL IMMUTABLE AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[show show_detail_fn]) }
        .to output(/show_detail_fn/).to_stdout
    end

    it 'raises FunctionNotFound when the function does not exist', :pgsql do
      expect { described_class.start(%w[show nonexistent_fn]) }
        .to raise_error(Arfi::Errors::FunctionNotFound, /nonexistent_fn/)
    end
  end
end
