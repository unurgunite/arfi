# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::PostgreSQL::DatabaseStatementsPatch, :pgsql do
  include ArfiSpec::TmpRoot

  before do
    write_function('db/functions/postgresql/public/arfi_auto.sql', <<~SQL)
      CREATE OR REPLACE FUNCTION arfi_auto() RETURNS int
      LANGUAGE sql IMMUTABLE AS $$ SELECT 42; $$;
    SQL
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS arfi_auto();')
  end

  it 'reloads functions and retries when a managed function is missing' do
    load_functions!
    val = ActiveRecord::Base.connection.select_value('SELECT arfi_auto()')
    expect(val).to eq(42)
  end

  it 'does not try to reload if function is not managed by ARFI' do
    expect do
      ActiveRecord::Base.connection.select_value('SELECT definitely_not_there()')
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end
