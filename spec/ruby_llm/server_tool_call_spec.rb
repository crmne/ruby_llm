# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ServerToolCall do
  it 'keeps search suggestions out of the hash it is stored as' do
    call = described_class.new(type: 'google_search', input: { 'queries' => ['ruby'] },
                               raw: { 'webSearchQueries' => ['ruby'] }, search_suggestions: '<div>Ruby</div>')

    expect(call.search_suggestions).to eq('<div>Ruby</div>')
    expect(call.to_h).to eq(type: 'google_search', input: { 'queries' => ['ruby'] },
                            raw: { 'webSearchQueries' => ['ruby'] })
    expect(described_class.from_h(call.to_h).search_suggestions).to be_nil
  end
end
