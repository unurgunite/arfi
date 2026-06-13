# frozen_string_literal: true

RSpec.describe Arfi::SqlTriggerLoader, :mysql do
  include ArfiSpec::TmpRoot

  before do
    write_function('db/functions/public/users.sql', <<~SQL)
      CREATE TABLE IF NOT EXISTS users (id serial PRIMARY KEY, name varchar(255));
    SQL
    Arfi::SqlFunctionLoader.load!(verbose: false)
  end

  it 'loads mysql triggers from db/triggers/mysql/public' do
    write_function('db/triggers/mysql/public/arfi_before_ins.sql', mysql_trigger_sql('arfi_before_ins'))
    load_triggers!
    expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_before_ins')).to be(true)
  end

  it 'ignores underscore-prefixed files' do
    write_function('db/triggers/mysql/public/_boom.sql', 'SELECT 1/0;')
    write_function('db/triggers/mysql/public/arfi_before_ins.sql', mysql_trigger_sql('arfi_before_ins'))
    load_triggers!
    expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_before_ins')).to be(true)
  end

  context 'when adapter-specific and generic exist' do
    before do
      write_function('db/triggers/mysql/public/arfi_echo.sql', <<~SQL)
        CREATE TRIGGER arfi_echo
          BEFORE INSERT ON users
          FOR EACH ROW
          SET NEW.name = 'adapter';
      SQL
      write_function('db/triggers/public/arfi_echo.sql', <<~SQL)
        CREATE TRIGGER arfi_echo
          BEFORE INSERT ON users
          FOR EACH ROW
          SET NEW.name = 'generic';
      SQL
    end

    it 'prefers adapter file over generic' do
      load_triggers!
      expect(ActiveRecord::Base.trigger_exists?('users', 'arfi_echo')).to be(true)
    end
  end
end
