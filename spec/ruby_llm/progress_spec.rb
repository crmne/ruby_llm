# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Progress do
  it 'reads the share of work done' do
    expect(described_class.new(value: 3, total: 12, message: 'Reading page 3 of 12').fraction).to eq(0.25)
  end

  it 'has no share without a value and a total' do
    expect(described_class.new(message: 'Downloading').fraction).to be_nil
    expect(described_class.new(value: 120).fraction).to be_nil
    expect(described_class.new(total: 12).fraction).to be_nil
  end

  it 'inspects as one line' do
    expect(described_class.new(value: 1, total: 2).inspect).to eq('#<RubyLLM::Progress value: 1, total: 2>')
  end
end
