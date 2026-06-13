# frozen_string_literal: true

require 'rails_helper'
require 'arfi/rspec/matchers'

RSpec.describe 'ARFI RSpec matchers', :pgsql do # rubocop:disable RSpec/DescribeClass
  describe 'have_arfi_function' do
    it 'passes when the function exists in the database' do
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE OR REPLACE FUNCTION public.arfi_test_fn()
        RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect('arfi_test_fn').to have_arfi_function
    end

    it 'fails when the function does not exist' do
      expect('arfi_nonexistent_fn').not_to have_arfi_function
    end
  end

  describe 'have_arfi_trigger' do
    it 'passes when the trigger exists on the given table' do # rubocop:disable RSpec/ExampleLength
      conn = ActiveRecord::Base.connection
      conn.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS arfi_test_trg_users (
          id serial PRIMARY KEY, name text
        );
      SQL
      conn.execute(<<~SQL)
        CREATE OR REPLACE FUNCTION public.arfi_test_trg_fn()
        RETURNS TRIGGER LANGUAGE plpgsql AS $$
        BEGIN RETURN NEW; END;
        $$;
      SQL
      conn.execute(<<~SQL)
        CREATE TRIGGER arfi_test_trg
          BEFORE INSERT ON arfi_test_trg_users
          FOR EACH ROW
          EXECUTE FUNCTION public.arfi_test_trg_fn();
      SQL

      expect('arfi_test_trg').to have_arfi_trigger.on_table('arfi_test_trg_users')
    end

    it 'fails when the trigger does not exist' do
      expect('arfi_nonexistent_trg').not_to have_arfi_trigger.on_table('arfi_test_trg_users')
    end

    it 'raises ArgumentError when .on_table is not called' do # rubocop:disable RSpec/MultipleExpectations
      expect { expect('any_trg').to have_arfi_trigger }
        .to raise_error(ArgumentError, /on_table/)
    end
  end
end
