# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe Arfi::SqlFunctionLoader do
  subject(:invoke_enhancer) { Rake::Task[enhancer]&.invoke if Rake::Task.task_defined?(enhancer) }

  let(:app) { Rake::Application.new }
  let(:enhancer) { '_db:arfi_enhance' }

  before do
    Rake.application = app
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application = nil
  end

  describe 'standard db tasks' do
    before do
      define_tasks('db:migrate', 'db:schema:load', 'db:setup', 'db:prepare', 'db:test:prepare')
      load_arfi_tasks
    end

    %w[db:migrate db:schema:load db:setup db:prepare db:test:prepare].each do |task|
      it "enhances #{task} with _db:arfi_enhance" do
        expect(Rake::Task[task].prerequisites).to include('_db:arfi_enhance')
      end
    end
  end

  describe 'suffixed db tasks' do
    before do
      define_tasks('db:migrate:animals', 'db:schema:load:animals', 'db:prepare:animals')
      load_arfi_tasks
    end

    %w[db:migrate:animals db:schema:load:animals db:prepare:animals].each do |task|
      it "defines enhancer for #{task}" do
        expect(Rake::Task.task_defined?("_db:arfi_enhance:#{task}")).to be(true)
      end

      it "adds enhancer to #{task} prerequisites" do
        expect(Rake::Task[task].prerequisites).to include("_db:arfi_enhance:#{task}")
      end
    end
  end

  describe 'dynamic enhancer' do
    before do
      define_tasks('db:migrate:animals')
      allow(ActiveRecord::Base).to receive(:establish_connection)
      configs = instance_double(ActiveRecord::DatabaseConfigurations)
      allow(configs).to receive(:configs_for).and_return([])
      allow(ActiveRecord::Base).to receive_messages(connection: Object.new, configurations: configs)
      allow(described_class).to receive(:load!)
      allow(Arfi::SqlTriggerLoader).to receive(:load!)
      load_arfi_tasks
    end

    it 'calls SqlFunctionLoader with task_name' do
      Rake::Task['_db:arfi_enhance:db:migrate:animals'].invoke
      expect(described_class).to have_received(:load!).with(
        task_name: 'db:migrate:animals', connection: anything, verbose: true
      )
    end

    it 'calls SqlTriggerLoader with task_name' do
      Rake::Task['_db:arfi_enhance:db:migrate:animals'].invoke
      expect(Arfi::SqlTriggerLoader).to have_received(:load!).with(
        task_name: 'db:migrate:animals', connection: anything, verbose: true
      )
    end
  end
end
