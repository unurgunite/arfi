# frozen_string_literal: true

RSpec.describe Arfi::SqlFunctionLoader, :db do
  include ArfiSpec::TmpRoot

  it 'loads generic functions from db/functions' do
    with_tmp_root do |root|
      root.join('db/functions/public/arfi_echo.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_echo() RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 'generic';
        $$;
      SQL

      described_class.load!(verbose: false)

      val = ActiveRecord::Base.connection.select_value('SELECT arfi_echo()')
      expect(val).to eq('generic')
    end
  end

  it 'prefers adapter-specific override db/functions/postgresql over db/functions' do
    with_tmp_root do |root|
      root.join('db/functions/public/arfi_echo.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_echo() RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 'generic';
        $$;
      SQL

      root.join('db/functions/public/arfi_echo.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_echo() RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 'postgres';
        $$;
      SQL

      described_class.load!(verbose: false)

      val = ActiveRecord::Base.connection.select_value('SELECT arfi_echo()')
      expect(val).to eq('postgres')
    end
  end

  it 'ignores underscore-prefixed sql files' do
    with_tmp_root do |root|
      root.join('db/functions/public/_boom.sql').write('SELECT 1/0;') # would explode if executed

      root.join('db/functions/public/arfi_ok.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_ok() RETURNS int
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 1;
        $$;
      SQL

      described_class.load!(verbose: false)
      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_ok()')).to eq(1)
    end
  end
end
