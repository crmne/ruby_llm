# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Streaming do
  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      obj.define_singleton_method(:build_chunk) { |data| "chunk:#{data['x']}" }
      obj.define_singleton_method(:parse_error) do |response|
        response.body.dig('error', 'message') if response.body.is_a?(Hash)
      end
    end
  end

  let(:env) { Faraday::Env.from(status: 200) }
  let(:parsed_error) { { 'error' => { 'message' => 'Rate limit exceeded' } } }

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

  it 'prefers the failed HTTP response status over a generic parsed stream status' do
    failed_env = Faraday::Env.from(status: 429)

    response = test_obj.send(:build_stream_error_response, parsed_error, failed_env, 500)

    expect(response.status).to eq(429)
    expect(response.body).to eq(parsed_error)
  end

  it 'uses the parsed stream status when the HTTP response status is successful' do
    response = test_obj.send(:build_stream_error_response, parsed_error, env, 529)

    expect(response.status).to eq(529)
  end

  it 'stores parsed streaming errors on the response env before raising' do
    failed_env = Faraday::Env.from(status: 429)

    expect do
      test_obj.send(:raise_stream_error, parsed_error.to_json, parsed_error, failed_env)
    end.to raise_error(RubyLLM::RateLimitError, 'Rate limit exceeded')

    response = failed_env[:streaming_error_response]
    expect(response.status).to eq(429)
    expect(response.body).to eq(parsed_error)
  end
end
