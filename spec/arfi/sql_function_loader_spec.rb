# frozen_string_literal: true

RSpec.describe Arfi::SqlFunctionLoader, :pgsql do
  include ArfiSpec::TmpRoot

  def load!
    described_class.load!(verbose: false)
  end

  def select_value(sql)
    ActiveRecord::Base.connection.select_value(sql)
  end

  before do
    write_function('db/functions/public/arfi_echo.sql', <<~SQL)
      CREATE OR REPLACE FUNCTION arfi_echo() RETURNS text
      LANGUAGE sql IMMUTABLE AS $$ SELECT 'generic'; $$;
    SQL
  end

  it 'loads generic functions from db/functions' do
    load!
    expect(select_value('SELECT arfi_echo()')).to eq('generic')
  end

  context 'when adapter-specific override exists' do
    before do
      write_function('db/functions/postgresql/public/arfi_echo.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION arfi_echo() RETURNS text
        LANGUAGE sql IMMUTABLE AS $$ SELECT 'postgres'; $$;
      SQL
    end

    it 'prefers adapter-specific override db/functions/postgresql over db/functions' do
      load!
      expect(select_value('SELECT arfi_echo()')).to eq('postgres')
    end
  end

  context 'when underscore-prefixed files exist' do
    before do
      write_function('db/functions/public/_boom.sql', 'SELECT 1/0;')
      write_function('db/functions/public/arfi_ok.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION arfi_ok() RETURNS int
        LANGUAGE sql IMMUTABLE AS $$ SELECT 1; $$;
      SQL
    end

    it 'ignores underscore-prefixed sql files' do
      load!
      expect(select_value('SELECT arfi_ok()')).to eq(1)
    end
  end
end
