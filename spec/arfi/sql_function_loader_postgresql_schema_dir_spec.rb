# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::SqlFunctionLoader, :pgsql do
  include ArfiSpec::TmpRoot

  def load!
    described_class.load!(verbose: false)
  end

  def write_schema_function(rel, sql)
    root.join(rel).tap { |p| FileUtils.mkdir_p(p.dirname) }.write(sql)
  end

  before do
    ActiveRecord::Base.connection.execute('CREATE SCHEMA IF NOT EXISTS audit;')
    write_schema_function('db/functions/postgresql/audit/arfi_audit.sql', <<~SQL)
      CREATE OR REPLACE FUNCTION audit.arfi_audit() RETURNS int
      LANGUAGE sql IMMUTABLE AS $$ SELECT 7; $$;
    SQL
  end

  it 'loads functions from db/functions/postgresql/<schema>' do
    load!
    expect(ActiveRecord::Base.connection.select_value('SELECT audit.arfi_audit()')).to eq(7)
  end
end
