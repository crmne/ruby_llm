# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ToolCall::Collection do
  let(:second) { RubyLLM::ToolCall.new(id: 'call_b', name: 'second') }
  let(:first_call) { RubyLLM::ToolCall.new(id: 'call_a', name: 'first') }
  let(:calls) { { 'call_b' => second, 'call_a' => first_call } }
  let(:collection) { described_class.new(calls) }

  it 'enumerates tool calls in provider order' do
    expect(collection.first).to be(second)
    expect(collection.map(&:name)).to eq(%w[second first])
    expect(collection.to_a).to eq([second, first_call])
    expect(collection.each.size).to eq(2)
  end

  it 'yields a call, not a pair' do
    expect { |probe| collection.each(&probe) }.to yield_successive_args(second, first_call)
  end

  it 'reads a call by ID' do
    expect(collection['call_a']).to be(first_call)
    expect(collection['missing']).to be_nil
    expect(collection.fetch('call_a')).to be(first_call)
    expect { collection.fetch('missing') }.to raise_error(KeyError)
  end

  it 'reports its size' do
    expect(collection.size).to eq(2)
    expect(collection.length).to eq(2)
    expect(collection).not_to be_empty
    expect(described_class.new).to be_empty
  end

  it 'keeps the Hash readers' do
    expect(collection.values).to eq([second, first_call])
    expect(collection.keys).to eq(%w[call_b call_a])
    expect(collection).to be_key('call_a')
    expect(collection).not_to be_key('missing')
    expect(collection.each_value.to_a).to eq([second, first_call])
    expect(collection.transform_values(&:name)).to eq('call_b' => 'second', 'call_a' => 'first')
  end

  it 'leaves out calls by ID' do
    expect(collection.except('call_b').to_a).to eq([first_call])
    expect(collection.size).to eq(2)
  end

  it 'equals an equivalent Hash from either side' do
    expect(collection).to eq(calls)
    expect(calls).to eq(collection)
    expect(described_class.new).to eq({})
    expect(collection).to eq(described_class.new(calls))
    expect(collection).not_to eq('call_a' => first_call)
    expect(collection).not_to eq([second, first_call])
    expect(collection).not_to be_nil
  end

  it 'converts to a Hash the caller owns' do
    copy = collection.to_h
    copy.clear

    expect(collection.to_h).to eq(calls)
    expect(collection.to_h { |id, call| [call.name, id] }).to eq('second' => 'call_b', 'first' => 'call_a')
  end

  it 'serializes to JSON the way a Hash does' do
    hash = { 'call_a' => { name: 'first' } }

    expect(described_class.new(hash).to_json).to eq(hash.to_json)
    expect(described_class.new(hash).as_json).to eq(hash.as_json)
  end

  it 'prints one short line' do
    expect(collection.inspect).to eq('#<RubyLLM::ToolCall::Collection calls: ["second", "first"]>')
  end
end
