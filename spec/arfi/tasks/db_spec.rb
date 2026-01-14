# frozen_string_literal: true

require 'rake'

RSpec.describe 'ARFI rake task enhancements' do
  it 'enhances db:schema:load with _db:arfi_enhance' do
    # isolate Rake state
    app = Rake::Application.new
    Rake.application = app

    Rake::Task.define_task(:environment)

    %w[db:migrate db:schema:load db:setup db:prepare db:test:prepare].each do |t|
      Rake::Task.define_task(t)
    end

    # stub Rails.database_configuration used by db.rake dynamic part
    allow(ActiveRecord::Base).to receive(:configurations).and_return({
                                                                       'test' => { 'primary' => { 'adapter' => 'postgresql' } }
                                                                     })

    load File.expand_path('../lib/arfi/tasks/db.rake', __dir__)

    expect(Rake::Task['db:schema:load'].prerequisites).to include('_db:arfi_enhance')
  ensure
    Rake.application = nil
  end
end
