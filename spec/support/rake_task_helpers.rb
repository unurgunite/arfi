# frozen_string_literal: true

module ArfiSpec
  module RakeTaskHelpers
    def define_tasks(*names)
      names.each { |n| Rake::Task.define_task(n) }
    end

    def load_arfi_tasks
      load File.expand_path('../../lib/arfi/tasks/db.rake', __dir__)
    end
  end
end
