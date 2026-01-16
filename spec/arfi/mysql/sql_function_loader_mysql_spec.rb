# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ARFI MySQL loader', :mysql do
  include ArfiSpec::TmpRoot

  it 'loads mysql/public functions' do
    with_tmp_root do |root|
      # mysql function (single statement; no delimiter issues)
      root.join('db/functions/mysql/public/arfi_ok.sql').write(<<~SQL)
        CREATE FUNCTION arfi_ok() RETURNS INT DETERMINISTIC RETURN 1;
      SQL

      Arfi::SqlFunctionLoader.load!(verbose: false)

      val = ActiveRecord::Base.connection.select_value('SELECT arfi_ok()')
      expect(val.to_i).to eq(1)
    end
  end

  it 'ignores underscore-prefixed files' do
    with_tmp_root do |root|
      root.join('db/functions/mysql/public/_boom.sql').write('SELECT 1/0;')
      root.join('db/functions/mysql/public/arfi_ok.sql').write(<<~SQL)
        CREATE FUNCTION arfi_ok() RETURNS INT DETERMINISTIC RETURN 1;
      SQL

      Arfi::SqlFunctionLoader.load!(verbose: false)

      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_ok()').to_i).to eq(1)
    end
  end

  it 'prefers adapter file over generic (and does not try to create twice)' do
    with_tmp_root do |root|
      # If loader executed BOTH, MySQL would fail on the second CREATE FUNCTION (already exists).
      root.join('db/functions/public/arfi_echo.sql').write(<<~SQL)
        CREATE FUNCTION arfi_echo() RETURNS VARCHAR(20) DETERMINISTIC RETURN 'generic';
      SQL

      root.join('db/functions/mysql/public/arfi_echo.sql').write(<<~SQL)
        CREATE FUNCTION arfi_echo() RETURNS VARCHAR(20) DETERMINISTIC RETURN 'mysql';
      SQL

      Arfi::SqlFunctionLoader.load!(verbose: false)

      val = ActiveRecord::Base.connection.select_value('SELECT arfi_echo()')
      expect(val).to eq('mysql')
    end
  end
end
