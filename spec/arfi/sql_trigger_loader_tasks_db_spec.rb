# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe Arfi::SqlTriggerLoader do
  let(:app) { Rake::Application.new }

  before do
    Rake.application = app
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application = nil
  end

  def define_tasks(*names)
    names.each { |n| Rake::Task.define_task(n) }
  end

  def load_arfi_tasks
    load File.expand_path('../../lib/arfi/tasks/db.rake', __dir__)
  end

  describe 'dynamic enhancer calls both loaders' do
    before do
      define_tasks('db:migrate:animals')
      allow(ActiveRecord::Base).to receive(:establish_connection)
      configs = instance_double(ActiveRecord::DatabaseConfigurations)
      allow(configs).to receive(:configs_for).and_return([])
      allow(ActiveRecord::Base).to receive_messages(connection: Object.new, configurations: configs)
      allow(Arfi::SqlFunctionLoader).to receive(:load!)
      allow(described_class).to receive(:load!)
      load_arfi_tasks
    end

    it 'calls SqlTriggerLoader alongside SqlFunctionLoader' do
      Rake::Task['_db:arfi_enhance:db:migrate:animals'].invoke
      expect(described_class).to have_received(:load!).with(
        task_name: 'db:migrate:animals', connection: anything, verbose: true
      )
    end
  end
end
