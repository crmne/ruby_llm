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

  it 'reads a streamed call by its ID when it is keyed by stream index' do
    streamed = described_class.new(0 => first_call)

    expect(streamed['call_a']).to be(first_call)
    expect(streamed.fetch('call_a')).to be(first_call)
    expect(streamed).to be_key('call_a')
    expect(streamed[0]).to be(first_call)
    expect(streamed['missing']).to be_nil
    expect(streamed.except('call_a')).to be_empty
  end

  it 'never matches a missing ID to a call without one' do
    fragment = described_class.new(0 => RubyLLM::ToolCall.new(name: nil))

    expect(fragment[nil]).to be_nil
    expect(fragment).not_to be_key(nil)
    expect { fragment.fetch(nil) }.to raise_error(KeyError)
    expect(fragment.except(nil).size).to eq(1)
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
    expect(collection.each_key.to_a).to eq(%w[call_b call_a])
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

  it 'gives its Hash as JSON data without Active Support' do
    hash = {}
    allow(hash).to receive(:respond_to?).and_call_original
    allow(hash).to receive(:respond_to?).with(:as_json).and_return(false)

    expect(described_class.new(hash).as_json).to eq(hash)
  end

  it 'prints one short line' do
    expect(collection.inspect).to eq('#<RubyLLM::ToolCall::Collection calls: ["second", "first"]>')
  end
end
