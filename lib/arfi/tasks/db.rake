# frozen_string_literal: true

require 'rake'

namespace :_db do
  task :arfi_enhance do
    puts 'Enhancing db:migrate task...'
    sql_functions = Dir.glob(Rails.root.join('db', 'functions', '*.sql')).map { |f| File.basename(f) }
    puts "Found SQL Functions: #{sql_functions.join(', ')}" if sql_functions.any?
  end
end

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)

if Rake::Task.task_defined?('db:migrate')
  Rake::Task['db:migrate'].enhance(['_db:arfi_enhance'])
else
  puts 'Warning: db:migrate task not found'
end
