# frozen_string_literal: true

RSpec.describe Arfi::SqlTriggerLoader, :pgsql do
  include ArfiSpec::TmpRoot

  def load!
    described_class.load!(verbose: false)
  end

  def select_value(sql)
    ActiveRecord::Base.connection.select_value(sql)
  end

  before do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE OR REPLACE FUNCTION public.arfi_before_insert()
      RETURNS TRIGGER
      LANGUAGE plpgsql AS $$
      BEGIN
        RETURN NEW;
      END;
      $$;
    SQL
    write_function('db/functions/public/users.sql', <<~SQL)
      CREATE TABLE IF NOT EXISTS users (id serial PRIMARY KEY, name text);
    SQL
  end

  def trigger_sql(name)
    <<~SQL
      CREATE TRIGGER #{name}
        BEFORE INSERT ON users
        FOR EACH ROW
        EXECUTE FUNCTION public.arfi_before_insert();
    SQL
  end

  it 'loads triggers from db/triggers' do
    write_function('db/triggers/public/arfi_before_ins.sql', trigger_sql('arfi_before_ins'))
    Arfi::SqlFunctionLoader.load!(verbose: false)
    load!
    expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_before_ins')).to be(true)
  end

  it 'ignores underscore-prefixed files' do
    write_function('db/triggers/public/_boom.sql', 'SELECT 1/0;')
    write_function('db/triggers/public/arfi_before_ins.sql', trigger_sql('arfi_before_ins'))
    Arfi::SqlFunctionLoader.load!(verbose: false)
    load!
    expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_before_ins')).to be(true)
  end

  context 'when adapter-specific override exists' do
    before do
      write_function('db/triggers/public/arfi_echo.sql', <<~SQL)
        CREATE TRIGGER arfi_echo
          BEFORE INSERT ON users
          FOR EACH ROW
          EXECUTE FUNCTION public.arfi_before_insert();
      SQL
      write_function('db/triggers/postgresql/public/arfi_echo.sql', <<~SQL)
        CREATE TRIGGER arfi_echo
          AFTER INSERT ON users
          FOR EACH ROW
          EXECUTE FUNCTION public.arfi_before_insert();
      SQL
    end

    it 'prefers adapter-specific override' do
      Arfi::SqlFunctionLoader.load!(verbose: false)
      load!
      expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_echo')).to be(true)
    end
  end
end
