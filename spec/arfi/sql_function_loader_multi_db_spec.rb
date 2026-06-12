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

  def db_config(**extra)
    { 'adapter' => 'postgresql', 'url' => ENV.fetch('ARFI_POSTGRES_URL') }.merge(extra)
  end

  let(:db_configs) do
    {
      'test' => {
        'primary' => db_config('schema_search_path' => 'arfi_primary,public'),
        'animals' => db_config('schema_search_path' => 'arfi_animals,public')
      }
    }
  end

  def with_temp_configs(configs)
    old = ActiveRecord::Base.configurations
    ActiveRecord::Base.configurations = ActiveRecord::DatabaseConfigurations.new(configs)
    described_class.load!(verbose: false)
    yield
  ensure
    ActiveRecord::Base.configurations = old
  end

  it 'loads functions into primary database' do
    with_temp_configs(db_configs) do
      ActiveRecord::Base.establish_connection(db_configs['test']['primary'])
      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_primary')
    end
  end

  it 'loads functions into animals database' do
    with_temp_configs(db_configs) do
      ActiveRecord::Base.establish_connection(db_configs['test']['animals'])
      expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_animals')
    end
  end
end
