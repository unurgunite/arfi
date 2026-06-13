# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::Functions do
  include ArfiSpec::TmpRoot

  describe 'validate' do
    it 'reports OK for a valid SQL function file', :pgsql do
      write_function('db/functions/public/valid_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION valid_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[validate --adapter=postgresql --format=paths]) }
        .to output(/OK/).to_stdout
    end

    it 'reports FAIL for invalid SQL syntax', :pgsql do
      write_function('db/functions/public/bad_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION bad_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT syntax_error; $$;
      SQL

      expect { described_class.start(%w[validate --adapter=postgresql --format=paths]) }
        .to output(/FAIL/).to_stdout
    end

    it 'does not leave functions in the database after validation on PostgreSQL', :pgsql do
      write_function('db/functions/public/transient_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION transient_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      described_class.start(%w[validate --adapter=postgresql --format=paths])

      expect(ActiveRecord::Base.function_exists?('transient_fn')).to be false
    end

    it 'reports OK via table format by default', :pgsql do
      write_function('db/functions/public/table_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION table_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[validate --adapter=postgresql]) }
        .to output(/table_fn.+OK/).to_stdout
    end

    it 'outputs valid JSON with --format=json', :pgsql do
      write_function('db/functions/public/json_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION json_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[validate --adapter=postgresql --format=json]) }
        .to output(/"status":\s*"OK"/).to_stdout
    end
  end

  describe 'doctor' do
    it 'reports OK for functions that exist in the database', :pgsql do
      write_function('db/functions/public/existing_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION existing_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE OR REPLACE FUNCTION existing_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[doctor --adapter=postgresql --format=paths]) }
        .to output(/OK/).to_stdout
    end

    it 'reports MISSING for functions not in the database', :pgsql do
      write_function('db/functions/public/missing_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION missing_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[doctor --adapter=postgresql --format=paths]) }
        .to output(/MISSING/).to_stdout
    end

    it 'outputs valid JSON with --format=json', :pgsql do
      write_function('db/functions/public/json_doc_fn.sql', <<~SQL)
        CREATE OR REPLACE FUNCTION json_doc_fn() RETURNS INT LANGUAGE SQL AS $$ SELECT 1; $$;
      SQL

      expect { described_class.start(%w[doctor --adapter=postgresql --format=json]) }
        .to output(/"status":\s*"MISSING"/).to_stdout
    end
  end
end
