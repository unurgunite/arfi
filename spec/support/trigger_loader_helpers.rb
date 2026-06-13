# frozen_string_literal: true

module ArfiSpec
  module TriggerLoaderHelpers
    def load_triggers!
      Arfi::SqlTriggerLoader.load!(verbose: false)
    end

    def trigger_sql(name)
      <<~SQL
        CREATE TRIGGER #{name}
          BEFORE INSERT ON users
          FOR EACH ROW
          EXECUTE FUNCTION public.arfi_before_insert();
      SQL
    end

    def mysql_trigger_sql(name)
      <<~SQL
        CREATE TRIGGER #{name}
          BEFORE INSERT ON users
          FOR EACH ROW
          SET NEW.name = 'triggered';
      SQL
    end
  end
end
