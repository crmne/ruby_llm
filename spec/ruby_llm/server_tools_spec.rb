# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ServerTools do
  it 'passes raw tool hashes with mixed key types through unchanged' do
    raw_tool = { 'type' => 'custom', name: 'mixed_keys' }

    expect(described_class.normalize([raw_tool], {})).to eq([{ raw: raw_tool }])
  end
end
