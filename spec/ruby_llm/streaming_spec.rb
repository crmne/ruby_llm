# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Streaming do
  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      obj.define_singleton_method(:build_chunk) { |data| "chunk:#{data['x']}" }
    end
  end

  let(:env) { Struct.new(:status).new(200) }

  before do
    stub_const('Faraday::VERSION', '2.0.0')
  end

  it 'skips non-hash SSE payloads' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    expect { handler.call("data: true\n\n", 0, env) }.not_to raise_error
    expect(yielded_chunks).to eq([])
  end

  it 'processes hash SSE payloads' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    handler.call("data: {\"x\":\"ok\"}\n\n", 0, env)

    expect(yielded_chunks).to eq(['chunk:ok'])
  end

  it 'parses nested provider error codes from streaming payloads' do
    status, message = test_obj.send(
      :parse_streaming_error,
      { error: { code: 529, message: 'Overloaded' } }.to_json
    )

    expect(status).to eq(529)
    expect(message).to eq('Overloaded')
  end

  it 'builds a minimal error response when Faraday v2 env is missing' do
    response = test_obj.send(:build_stream_error_response, { 'error' => { 'message' => 'oops' } }, nil, 500)

    expect(response.body).to eq({ 'error' => { 'message' => 'oops' } })
    expect(response.status).to eq(500)
  end

  it 'treats nil env as a normal chunk in the v2 on_data handler' do
    yielded_chunks = []
    failed_chunks = []
    handler = described_class::FaradayHandlers.send(
      :v2_on_data,
      ->(chunk, env) { yielded_chunks << [chunk, env] },
      ->(chunk, env) { failed_chunks << [chunk, env] }
    )

    handler.call("data: {\"x\":\"ok\"}\n\n", 0, nil)

    expect(yielded_chunks).to eq([["data: {\"x\":\"ok\"}\n\n", nil]])
    expect(failed_chunks).to be_empty
  end
end
