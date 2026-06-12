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

  def load!
    described_class.load!(verbose: false)
  end

  def expect_index_creation_to_fail
    expect do
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE INDEX idx_users_norm_email ON users (normalize_email(email));
      SQL
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  def expect_index_creation_to_succeed
    expect do
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE INDEX idx_users_norm_email ON users (normalize_email(email));
      SQL
    end.not_to raise_error(ActiveRecord::StatementInvalid)
  end

  it 'fails on index creation when function is missing' do
    expect_index_creation_to_fail
  end

  it 'succeeds after loader provides the function' do
    load!
    expect_index_creation_to_succeed
  end
end
