# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ARFI multi-db loader', :pgsql do
  include ArfiSpec::TmpRoot

  it 'loads functions into each configured database when task_name is nil' do
    skip unless defined?(ActiveRecord::DatabaseConfigurations)

    with_tmp_root do |root|
      # create two schemas in the same DB (public reset won't remove these)
      ActiveRecord::Base.connection.execute('DROP SCHEMA IF EXISTS arfi_primary CASCADE')
      ActiveRecord::Base.connection.execute('CREATE SCHEMA arfi_primary')
      ActiveRecord::Base.connection.execute('DROP SCHEMA IF EXISTS arfi_animals CASCADE')
      ActiveRecord::Base.connection.execute('CREATE SCHEMA arfi_animals')

      # unqualified CREATE FUNCTION -> created in first schema in search_path
      root.join('db/functions/public/arfi_multi.sql').write(<<~SQL)
        CREATE OR REPLACE FUNCTION arfi_multi() RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
          SELECT current_schema();
        $$;
      SQL

      primary = {
        'adapter' => 'postgresql',
        'url' => ENV.fetch('ARFI_POSTGRES_URL'),
        'schema_search_path' => 'arfi_primary,public'
      }

      animals = {
        'adapter' => 'postgresql',
        'url' => ENV.fetch('ARFI_POSTGRES_URL'),
        'schema_search_path' => 'arfi_animals,public'
      }

      configs = {
        'test' => {
          'primary' => primary,
          'animals' => animals
        }
      }

      old_configs = ActiveRecord::Base.configurations
      ActiveRecord::Base.configurations = ActiveRecord::DatabaseConfigurations.new(configs)

      begin
        Arfi::SqlFunctionLoader.load!(verbose: false)

        ActiveRecord::Base.establish_connection(primary)
        expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_primary')

        ActiveRecord::Base.establish_connection(animals)
        expect(ActiveRecord::Base.connection.select_value('SELECT arfi_multi()')).to eq('arfi_animals')
      ensure
        ActiveRecord::Base.configurations = old_configs
      end
    end
  end
end
