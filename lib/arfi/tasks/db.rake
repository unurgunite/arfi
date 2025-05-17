# frozen_string_literal: true

require 'rake'
require 'arfi/sql_function_loader'

namespace :_db do
  task :arfi_enhance do
    Arfi::SqlFunctionLoader.load!
  end
end

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)

# Enhancing single db tasks
%w[db:migrate db:schema:load db:setup db:prepare].each do |task|
  Rake::Task[task].enhance(['_db:arfi_enhance']) if Rake::Task.task_defined?(task)
end

# We remove user defined keys in database.yml and use only the ones about RDBMS connections.
# Here we try to find tasks like db:migrate:your_db_name and enhance them as well as tasks for single db connections.
rdbms_configs = Rails.configuration.database_configuration[Rails.env].select { |_k, v| v.is_a?(Hash) }.keys
possible_tasks = Rake::Task.tasks.select { _1.name.match?(/^(db:migrate:|db:schema:load:|db:setup:|db:prepare:)(\w+)$/) }
possible_tasks = possible_tasks.select do |task|
  rdbms_configs.any? { |n| task.name.include?(n) }
end

# In general, this is a small trick due to the fact that Rake does not allow you to view parent tasks from a task that
# was called for enhancing. Moreover, the utility does not provide for passing parameters to the called task.
# To get around this limitation, we dynamically create a task with the name we need, and then pass this name as
# an argument to the method.
possible_tasks.each do |task|
  Rake::Task.define_task("_db:arfi_enhance:#{task.name}") do
    Arfi::SqlFunctionLoader.load!(task_name: task.name)
  end
  task.enhance(["_db:arfi_enhance:#{task.name}"])
end
