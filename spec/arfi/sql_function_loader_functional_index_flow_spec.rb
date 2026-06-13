# frozen_string_literal: true

# functional index flow
RSpec.describe Arfi::SqlFunctionLoader, :pgsql do
  include ArfiSpec::TmpRoot

  before do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE users (id bigserial primary key, email text);
    SQL
    write_function('db/functions/postgresql/public/normalize_email.sql', <<~SQL)
      CREATE OR REPLACE FUNCTION normalize_email(val text) RETURNS text
      LANGUAGE sql IMMUTABLE AS $$ SELECT lower(val); $$;
    SQL
  end

  it 'succeeds via auto-reload when function is ARFI-managed' do
    expect_index_creation_to_succeed
  end

  it 'succeeds after loader provides the function' do
    load_functions!
    expect_index_creation_to_succeed
  end
end
