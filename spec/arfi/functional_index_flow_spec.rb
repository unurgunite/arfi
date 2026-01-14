# frozen_string_literal: true

RSpec.describe 'functional index flow', :db do
  include ArfiSpec::TmpRoot

  it 'fails without function, succeeds after loader' do
    with_tmp_root do |root|
      # table
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE TABLE users (id bigserial primary key, email text);
      SQL

      # index referencing missing function => should error
      expect do
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE INDEX idx_users_norm_email ON users (normalize_email(email));
        SQL
      end.to raise_error(ActiveRecord::StatementInvalid) { |err|
        expect(err.cause).to be_a(PG::UndefinedFunction)
      }

      # provide function definition
      root.join('db/functions/postgresql/public/normalize_email.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION normalize_email(val text) RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
          SELECT lower(val);
        $$;
      SQL

      Arfi::SqlFunctionLoader.load!(verbose: false)
      expect do
        # now index creation succeeds
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE INDEX idx_users_norm_email ON users (normalize_email(email));
        SQL
      end.not_to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
