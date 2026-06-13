# frozen_string_literal: true

module ArfiSpec
  module DbHelpers
    def select_value(sql)
      ActiveRecord::Base.connection.select_value(sql)
    end
  end
end
