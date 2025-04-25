# frozen_string_literal: true

require 'rake'
require 'arfi/sql_function_loader'

namespace :_db do
  task :arfi_enhance do
    Arfi::SqlFunctionLoader.load!
  end
end

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
raise UnrecognizedCommandError, 'Warning: db:migrate task not found' unless Rake::Task.task_defined?('db:migrate')

%w[db:migrate db:schema:load db:setup db:prepare].each do |task|
  Rake::Task[task].enhance(['_db:arfi_enhance']) if Rake::Task.task_defined?(task)
end
