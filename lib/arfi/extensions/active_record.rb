# frozen_string_literal: true

require 'active_record/base'

module ActiveRecord
  class Base # :nodoc:
    def self.function_exists?(function_name)
      connection.execute("SELECT * FROM pg_proc WHERE proname = '#{function_name}'").any?
    end
  end
end
