# frozen_string_literal: true

RSpec.describe Arfi::SqlFunctionLoader, :mysql do
  include ArfiSpec::TmpRoot

  def load!
    described_class.load!(verbose: false)
  end

  def select_value(sql)
    ActiveRecord::Base.connection.select_value(sql)
  end

  before do
    write_function('db/functions/mysql/public/arfi_ok.sql', <<~SQL)
      CREATE FUNCTION arfi_ok() RETURNS INT DETERMINISTIC RETURN 1;
    SQL
  end

  it 'loads mysql/public functions' do
    load!
    expect(select_value('SELECT arfi_ok()').to_i).to eq(1)
  end

  it 'ignores underscore-prefixed files' do
    write_function('db/functions/mysql/public/_boom.sql', 'SELECT 1/0;')
    load!
    expect(select_value('SELECT arfi_ok()').to_i).to eq(1)
  end

  context 'when generic and adapter-specific files exist' do
    before do
      write_function('db/functions/public/arfi_echo.sql', <<~SQL)
        CREATE FUNCTION arfi_echo() RETURNS VARCHAR(20) DETERMINISTIC RETURN 'generic';
      SQL
      write_function('db/functions/mysql/public/arfi_echo.sql', <<~SQL)
        CREATE FUNCTION arfi_echo() RETURNS VARCHAR(20) DETERMINISTIC RETURN 'mysql';
      SQL
    end

    it 'prefers adapter file over generic' do
      load!
      expect(select_value('SELECT arfi_echo()')).to eq('mysql')
    end
  end
end
