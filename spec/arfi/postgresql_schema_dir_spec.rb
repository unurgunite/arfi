# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ARFI schema dir loading', :db do
  include ArfiSpec::TmpRoot

  it 'loads functions from db/functions/postgresql/<schema> and allows schema-qualified calls' do
    with_tmp_root do |root|
      ActiveRecord::Base.connection.execute('CREATE SCHEMA IF NOT EXISTS audit;')

      root.join('db/functions/postgresql/audit/arfi_audit.sql').tap { |p| FileUtils.mkdir_p(p.dirname) }.write(<<~SQL)
        CREATE OR REPLACE FUNCTION audit.arfi_audit() RETURNS int
        LANGUAGE sql IMMUTABLE AS $$
          SELECT 7;
        $$;
      SQL

      Arfi::SqlFunctionLoader.load!(verbose: false)

      expect(ActiveRecord::Base.connection.select_value('SELECT audit.arfi_audit()')).to eq(7)
    end
  end
end
