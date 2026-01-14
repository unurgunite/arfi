# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Arfi::Commands::FIdx do
  it 'is an alias of Arfi::Commands::Functions' do
    expect(described_class).to eq(Arfi::Commands::Functions)
  end
end
