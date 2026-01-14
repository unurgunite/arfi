# frozen_string_literal: true

require 'rake'
require 'active_record'
require 'arfi/sql_function_loader'

namespace :_db do
  task :arfi_enhance do
    # For non-suffixed tasks (db:migrate / db:prepare etc),
    # loader will populate all DBs when multi-db and task_name is nil.
    Arfi::SqlFunctionLoader.load!(verbose: true)
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

def arfi_db_config_for(name)
  # Rails 6/7+ preferred way
  if ActiveRecord::Base.respond_to?(:configurations) && ActiveRecord::Base.configurations
    cfg = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name).first
    return cfg&.configuration_hash
  end

  nil
end

# Enhance suffixed tasks: db:migrate:<db>, db:schema:load:<db>, etc.
pattern = /^(db:migrate:|db:schema:load:|db:setup:|db:prepare:|db:test:prepare:)([^:]+)$/
possible_tasks = Rake::Task.tasks.select { |t| t.name.match?(pattern) }

possible_tasks.each do |task|
  db_name = task.name.match(pattern)[2]

  Rake::Task.define_task("_db:arfi_enhance:#{task.name}") do
    # Connect explicitly to the named DB so we load functions into the correct target.
    config_hash = arfi_db_config_for(db_name)

    if config_hash
      original_config = begin
        ActiveRecord::Base.connection_db_config
      rescue StandardError
        nil
      end

      begin
        ActiveRecord::Base.establish_connection(config_hash)
        Arfi::SqlFunctionLoader.load!(
          task_name: task.name,
          connection: ActiveRecord::Base.connection,
          verbose: true
        )
      ensure
        # Restore previous connection if we had one
        ActiveRecord::Base.establish_connection(original_config) if original_config
      end
    else
      # Fallback: use current connection
      Arfi::SqlFunctionLoader.load!(
        task_name: task.name,
        connection: ActiveRecord::Base.connection,
        verbose: true
      )
    end
  end

  task.enhance(["_db:arfi_enhance:#{task.name}"])
end
