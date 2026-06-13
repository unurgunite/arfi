# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::SqlFunctionLoader, :pgsql do
  include ArfiSpec::TmpRoot

  before do
    skip unless defined?(ActiveRecord::DatabaseConfigurations)
    ActiveRecord::Base.connection.execute('DROP SCHEMA IF EXISTS arfi_primary CASCADE')
    ActiveRecord::Base.connection.execute('CREATE SCHEMA arfi_primary')
    ActiveRecord::Base.connection.execute('DROP SCHEMA IF EXISTS arfi_animals CASCADE')
    ActiveRecord::Base.connection.execute('CREATE SCHEMA arfi_animals')
    write_function('db/functions/public/arfi_multi.sql', <<~SQL)
      CREATE OR REPLACE FUNCTION arfi_multi() RETURNS text
      LANGUAGE sql IMMUTABLE AS $$ SELECT current_schema(); $$;
    SQL
  end

  let(:db_configs) do
    {
      'test' => {
        'primary' => db_config('schema_search_path' => 'arfi_primary,public'),
        'animals' => db_config('schema_search_path' => 'arfi_animals,public')
      }
    }
  end

  it 'loads functions into primary database' do
    with_db_configs(db_configs) do
      ActiveRecord::Base.establish_connection(db_configs['test']['primary'])
      load_functions!
      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_primary')
    end
  end

  it 'loads functions into animals database' do
    with_db_configs(db_configs) do
      ActiveRecord::Base.establish_connection(db_configs['test']['animals'])
      load_functions!
      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_animals')
    end
  end

  it 'restores the original connection config after multi-db loading' do
    with_db_configs(db_configs) do
      original = ActiveRecord::Base.connection_db_config.name
      load_functions!
      expect(ActiveRecord::Base.connection_db_config.name).to eq(original)
    end
  end

  it 'leaves the original connection functional after multi-db loading' do
    with_db_configs(db_configs) do
      ActiveRecord::Base.connection.select_value('SELECT 1')
      load_functions!
      expect(ActiveRecord::Base.connection.select_value('SELECT 1')).to eq(1)
    end
  end

  it 'skips clear_active_connections when disabled' do
    with_db_configs(db_configs) do
      allow(ActiveRecord::Base.connection_handler).to receive(:clear_active_connections!)
      described_class.load!(verbose: false, clear_active_connections: false)
      expect(ActiveRecord::Base.connection_handler).not_to have_received(:clear_active_connections!)
    end
  end
end
