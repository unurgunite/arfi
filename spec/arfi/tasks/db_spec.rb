# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'ARFI rake task enhancements' do
  it 'enhances standard db tasks with _db:arfi_enhance' do
    app = Rake::Application.new
    Rake.application = app

    Rake::Task.define_task(:environment)

    %w[db:migrate db:schema:load db:setup db:prepare db:test:prepare].each do |t|
      Rake::Task.define_task(t)
    end

    load File.expand_path('../../../lib/arfi/tasks/db.rake', __dir__)

    %w[db:migrate db:schema:load db:setup db:prepare db:test:prepare].each do |t|
      expect(Rake::Task[t].prerequisites).to include('_db:arfi_enhance')
    end
  ensure
    Rake.application = nil
  end

  it 'enhances suffixed db tasks (db:migrate:animals) with a dynamic enhancer task' do
    app = Rake::Application.new
    Rake.application = app

    Rake::Task.define_task(:environment)

    # Define suffixed tasks like Rails multi-db creates
    %w[
      db:migrate:animals
      db:schema:load:animals
      db:prepare:animals
    ].each do |t|
      Rake::Task.define_task(t)
    end

    load File.expand_path('../../../lib/arfi/tasks/db.rake', __dir__)

    %w[
      db:migrate:animals
      db:schema:load:animals
      db:prepare:animals
    ].each do |t|
      enhancer = "_db:arfi_enhance:#{t}"
      expect(Rake::Task.task_defined?(enhancer)).to be(true)
      expect(Rake::Task[t].prerequisites).to include(enhancer)
    end
  ensure
    Rake.application = nil
  end

  it 'dynamic enhancer calls SqlFunctionLoader with task_name' do
    app = Rake::Application.new
    Rake.application = app

    Rake::Task.define_task(:environment)
    Rake::Task.define_task('db:migrate:animals')

    # Prevent db.rake from touching real AR configs / real connections
    allow(ActiveRecord::Base).to receive(:establish_connection)

    configs = double('db_configs')
    allow(configs).to receive(:configs_for).and_return([]) # accepts any args/kwargs
    allow(ActiveRecord::Base).to receive_messages(connection: Object.new, configurations: configs)

    allow(Arfi::SqlFunctionLoader).to receive(:load!)

    load File.expand_path('../../../lib/arfi/tasks/db.rake', __dir__)

    enhancer = '_db:arfi_enhance:db:migrate:animals'
    Rake::Task[enhancer].invoke

    expect(Arfi::SqlFunctionLoader).to have_received(:load!).with(hash_including(
                                                                    task_name: 'db:migrate:animals',
                                                                    verbose: true
                                                                  ))
  ensure
    Rake.application = nil
  end
end
