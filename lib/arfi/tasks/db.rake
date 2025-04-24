# frozen_string_literal: true

require 'rake'

namespace :_db do
  task :arfi_enhance do
    puts 'Enhancing db:migrate task...'
    db_config = Rails.configuration.database_configuration[Rails.env]
    pg_options = { user: db_config['username'], password: db_config['password'], host: db_config['host'],
                   port: db_config['port'], dbname: db_config['database'] }
    local_connection = PG.connect(**pg_options)
    sql_functions = Dir.glob(Rails.root.join('db', 'functions', '*.sql')).map { |f| File.basename(f) }
    puts "Found SQL Functions: #{sql_functions.join(', ')}" if sql_functions.any?
    sql_functions.flat_map { Dir.glob(Rails.root.join('db', 'functions', _1).to_s) }.each do |function|
      local_connection.async_exec(File.read(function).chop)
    end
    puts 'New functions ready for execution'
  end
end

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
raise UnrecognizedCommandError, 'Warning: db:migrate task not found' unless Rake::Task.task_defined?('db:migrate')

Rake::Task['db:migrate'].enhance(['_db:arfi_enhance'])
