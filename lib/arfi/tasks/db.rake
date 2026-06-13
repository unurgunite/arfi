# frozen_string_literal: true

require 'rake'
require 'active_record'
require 'arfi/sql_function_loader'
require 'arfi/sql_trigger_loader'

namespace :_db do
  task :arfi_enhance do
    Arfi::SqlFunctionLoader.load!(verbose: true)
    Arfi::SqlTriggerLoader.load!(verbose: true)
  end
end

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)

# Enhance common single-db tasks (and multi-db "default" tasks)
%w[
  db:migrate
  db:schema:load
  db:setup
  db:prepare
  db:test:prepare
].each do |task|
  Rake::Task[task].enhance(['_db:arfi_enhance']) if Rake::Task.task_defined?(task)
end

def define_arfi_enhance_for(task, db_name)
  Rake::Task.define_task("_db:arfi_enhance:#{task.name}") do
    run_arfi_loader_for(task, arfi_db_config_for(db_name))
  end
  task.enhance(["_db:arfi_enhance:#{task.name}"])
end

def run_arfi_loader_for(task, config_hash)
  if config_hash
    run_with_connection_switch(task, config_hash)
  else
    run_arfi_loader(task)
  end
end

def run_with_connection_switch(task, config_hash)
  original = current_db_config
  ActiveRecord::Base.establish_connection(config_hash)
  run_arfi_loader(task)
ensure
  ActiveRecord::Base.establish_connection(original) if original
end

def current_db_config
  ActiveRecord::Base.connection_db_config
rescue StandardError
  nil
end

def run_arfi_loader(task)
  Arfi::SqlFunctionLoader.load!(
    task_name: task.name,
    connection: ActiveRecord::Base.connection,
    verbose: true
  )
  Arfi::SqlTriggerLoader.load!(
    task_name: task.name,
    connection: ActiveRecord::Base.connection,
    verbose: true
  )
end

def arfi_db_config_for(name)
  return unless ActiveRecord::Base.respond_to?(:configurations) && ActiveRecord::Base.configurations

  list = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
  cfg = Array(list).first
  cfg&.configuration_hash
end

# Enhance suffixed tasks: db:migrate:<db>, db:schema:load:<db>, etc.
pattern = /^(db:migrate:|db:schema:load:|db:setup:|db:prepare:|db:test:prepare:)([^:]+)$/
possible_tasks = Rake::Task.tasks.select { |t| t.name.match?(pattern) }

possible_tasks.each do |task|
  db_name = task.name.match(pattern)[2]
  define_arfi_enhance_for(task, db_name)
end
