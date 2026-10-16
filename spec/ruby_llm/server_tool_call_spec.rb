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

  it 'rebuilds a stored call with its payloads as they were stored' do
    stored = { 'type' => 'web_search_call', 'id' => 'ws_1', 'input' => { 'query' => 'ruby' },
               'result' => [{ 'url' => 'https://www.ruby-lang.org' }],
               'raw' => { 'type' => 'web_search_call', 'action' => { 'query' => 'ruby' } } }

    call = described_class.from_h(stored)

    expect(call.type).to eq('web_search_call')
    expect(call.id).to eq('ws_1')
    expect(call.input).to eq('query' => 'ruby')
    expect(call.result).to eq([{ 'url' => 'https://www.ruby-lang.org' }])
    expect(call.raw).to eq('type' => 'web_search_call', 'action' => { 'query' => 'ruby' })
  end
end
