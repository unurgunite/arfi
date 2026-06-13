# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::Triggers, :pgsql do
  include ArfiSpec::TmpRoot
  include ArfiSpec::TriggerLoaderHelpers

  before do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS arfi_users (
        id serial PRIMARY KEY, name text
      );
    SQL
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE OR REPLACE FUNCTION public.trg_fn()
      RETURNS TRIGGER LANGUAGE plpgsql AS $$
      BEGIN RETURN NEW; END;
      $$;
    SQL
  end

  after do
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS public.trg_fn() CASCADE;')
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS arfi_users CASCADE;')
  end

  let(:trg_sql) do
    'CREATE TRIGGER trg BEFORE INSERT ON arfi_users FOR EACH ROW EXECUTE FUNCTION public.trg_fn();'
  end

  describe 'validate' do
    it 'reports OK for a valid SQL trigger file' do
      write_function('db/triggers/public/valid_trg.sql', trg_sql)

      expect { described_class.start(%w[validate --adapter=postgresql --format=paths]) }
        .to output(/OK/).to_stdout
    end

    it 'reports FAIL for invalid SQL syntax' do
      write_function('db/triggers/public/bad_trg.sql', 'CREATE TRIGGER syntax_error ON')

      expect { described_class.start(%w[validate --adapter=postgresql --format=paths]) }
        .to output(/FAIL/).to_stdout
    end

    it 'does not leave triggers in the database after validation on PostgreSQL' do
      write_function('db/triggers/public/transient_trg.sql', trg_sql)

      described_class.start(%w[validate --adapter=postgresql --format=paths])

      expect(ActiveRecord::Base.trigger_exists?('arfi_users', 'trg')).to be false
    end

    it 'reports OK via table format by default' do
      write_function('db/triggers/public/table_trg.sql', trg_sql)

      expect { described_class.start(%w[validate --adapter=postgresql]) }
        .to output(/table_trg.+OK/).to_stdout
    end

    it 'outputs valid JSON with --format=json' do
      write_function('db/triggers/public/json_trg.sql', trg_sql)

      expect { described_class.start(%w[validate --adapter=postgresql --format=json]) }
        .to output(/"status":\s*"OK"/).to_stdout
    end
  end

  describe 'doctor' do
    it 'reports OK for triggers that exist in the database' do
      sql = 'CREATE TRIGGER existing_trg BEFORE INSERT ON arfi_users FOR EACH ROW EXECUTE FUNCTION public.trg_fn();'
      write_function('db/triggers/public/existing_trg.sql', sql)
      ActiveRecord::Base.connection.execute(sql)
      expect { described_class.start(%w[doctor --adapter=postgresql --format=paths]) }.to output(/OK/).to_stdout
    end

    it 'reports MISSING for triggers not in the database' do
      write_function('db/triggers/public/missing_trg.sql', trg_sql)

      expect { described_class.start(%w[doctor --adapter=postgresql --format=paths]) }
        .to output(/MISSING/).to_stdout
    end

    it 'outputs valid JSON with --format=json' do
      write_function('db/triggers/public/json_doc_trg.sql', trg_sql)

      expect { described_class.start(%w[doctor --adapter=postgresql --format=json]) }
        .to output(/"status":\s*"MISSING"/).to_stdout
    end

    it 'shows the table name in doctor output' do
      write_function('db/triggers/public/table_check_trg.sql', trg_sql)

      expect { described_class.start(%w[doctor --adapter=postgresql --format=json]) }
        .to output(/"table":\s*"arfi_users"/).to_stdout
    end
  end
end
