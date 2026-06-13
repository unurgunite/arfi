# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::Functions do
  include ArfiSpec::TmpRoot

  it 'prints effective file paths (adapter overrides generic)' do
    write_function('db/functions/public/arfi_echo.sql')
    write_function('db/functions/postgresql/public/arfi_echo.sql')
    expect { described_class.start(%w[list --adapter=postgresql --format=paths]) }
      .to output(%r{db/functions/postgresql/public/arfi_echo\.sql}).to_stdout
  end

  it 'ignores underscore-prefixed sql files' do
    write_function('db/functions/public/_boom.sql', 'SELECT 1/0;')
    write_function('db/functions/public/ok.sql')
    expect { described_class.start(%w[list --adapter=postgresql --format=paths]) }
      .to output(%r{db/functions/public/ok\.sql}).to_stdout
  end

  it 'shows shadowed candidates with --all' do
    write_function('db/functions/public/arfi_echo.sql')
    write_function('db/functions/postgresql/public/arfi_echo.sql')
    expect { described_class.start(%w[list --adapter=postgresql --all --format=table]) }
      .to output(/chosen|shadowed_by/).to_stdout
  end
end
