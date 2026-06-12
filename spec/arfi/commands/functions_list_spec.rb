# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::Functions do
  include ArfiSpec::TmpRoot

  it 'prints effective file paths (adapter overrides generic)' do
    with_tmp_root do |root|
      root.join('db/functions/public/arfi_echo.sql').write("-- generic\n")
      root.join('db/functions/postgresql/public/arfi_echo.sql').write("-- override\n")

      expect do
        described_class.start(['list', '--adapter=postgresql', '--format=paths'])
      end.to output(%r{db/functions/postgresql/public/arfi_echo\.sql}).to_stdout
    end
  end

  it 'ignores underscore-prefixed sql files' do
    with_tmp_root do |root|
      root.join('db/functions/public/_boom.sql').write('SELECT 1/0;')
      root.join('db/functions/public/ok.sql').write("-- ok\n")

      expect do
        described_class.start(['list', '--adapter=postgresql', '--format=paths'])
      end.to output(%r{db/functions/public/ok\.sql}).to_stdout
    end
  end

  it 'shows shadowed candidates with --all' do
    with_tmp_root do |root|
      root.join('db/functions/public/arfi_echo.sql').write("-- generic\n")
      root.join('db/functions/postgresql/public/arfi_echo.sql').write("-- override\n")

      expect do
        described_class.start(['list', '--adapter=postgresql', '--all', '--format=table'])
      end.to output(/chosen|shadowed_by/).to_stdout
    end
  end
end
