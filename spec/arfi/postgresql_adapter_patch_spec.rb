# frozen_string_literal: true

RSpec.describe 'ARFI Postgres DatabaseStatementsPatch' do
  include ArfiSpec::TmpRoot

  it 'reloads functions and retries when a managed function is missing' do
    with_tmp_root do |root|
      root.join('db/functions/postgresql/arfi_auto.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_auto() RETURNS int
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 42;
        $$;
      SQL

      # ensure missing
      ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS arfi_auto();')

      # should fail once, trigger reload, then succeed
      val = ActiveRecord::Base.connection.select_value('SELECT arfi_auto()')
      expect(val).to eq(42)
    end
  end

  it 'does not try to reload if function is not managed by ARFI' do
    with_tmp_root do |_root|
      expect do
        ActiveRecord::Base.connection.select_value('SELECT definitely_not_there()')
      end.to raise_error(PG::UndefinedFunction)
    end
  end
end
