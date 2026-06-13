# frozen_string_literal: true

module ArfiSpec
  module FunctionLoaderHelpers
    def load_functions!
      Arfi::SqlFunctionLoader.load!(verbose: false)
    end

    def expect_index_creation_to_succeed
      expect do
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE INDEX idx_users_norm_email ON users (normalize_email(email));
        SQL
      end.not_to raise_error
    end

    def db_config(**extra)
      { 'adapter' => 'postgresql', 'url' => ENV.fetch('ARFI_POSTGRES_URL') }.merge(extra)
    end

    def with_db_configs(configs, &block)
      old = ActiveRecord::Base.configurations
      ActiveRecord::Base.configurations = ActiveRecord::DatabaseConfigurations.new(configs)
      yield
    ensure
      ActiveRecord::Base.configurations = old
    end
  end
end
