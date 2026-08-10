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

  # Faraday 2 with the net_http adapter invokes on_data with a nil env (the
  # status is not yet known mid-stream). The handler must process such chunks
  # normally rather than treating them as a failed response and discarding them.
  it 'processes chunks when env is nil (status not yet known)' do
    yielded_chunks = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded_chunks << chunk }

    handler.call("data: {\"x\":\"ok\"}\n\n", 0, nil)

    expect(yielded_chunks).to eq(['chunk:ok'])
  end

  describe RubyLLM::Streaming::FaradayHandlers do
    describe '.v2_on_data' do
      it 'routes the chunk to on_chunk when env is nil (status unknown)' do
        on_chunk_calls = []
        on_failed_calls = []
        handler = described_class.v2_on_data(
          ->(chunk, faraday_env) { on_chunk_calls << [chunk, faraday_env] },
          ->(chunk, faraday_env) { on_failed_calls << [chunk, faraday_env] }
        )

        handler.call('frame', 5, nil)

        expect(on_chunk_calls).to eq([['frame', nil]])
        expect(on_failed_calls).to be_empty
      end

      it 'routes the chunk to on_chunk when env reports a 200 status' do
        on_chunk_calls = []
        on_failed_calls = []
        ok_env = Struct.new(:status).new(200)
        handler = described_class.v2_on_data(
          ->(chunk, faraday_env) { on_chunk_calls << [chunk, faraday_env] },
          ->(chunk, faraday_env) { on_failed_calls << [chunk, faraday_env] }
        )

        handler.call('frame', 5, ok_env)

        expect(on_chunk_calls).to eq([['frame', ok_env]])
        expect(on_failed_calls).to be_empty
      end

      it 'routes the chunk to on_failed_response when env reports a non-200 status' do
        on_chunk_calls = []
        on_failed_calls = []
        err_env = Struct.new(:status).new(403)
        handler = described_class.v2_on_data(
          ->(chunk, faraday_env) { on_chunk_calls << [chunk, faraday_env] },
          ->(chunk, faraday_env) { on_failed_calls << [chunk, faraday_env] }
        )

        handler.call('error-frame', 11, err_env)

        expect(on_failed_calls).to eq([['error-frame', err_env]])
        expect(on_chunk_calls).to be_empty
      end
    end
  end

  it 'logs each chunk when stream debugging is on' do
    allow(RubyLLM.config).to receive(:log_stream_debug).and_return(true)
    allow(RubyLLM.logger).to receive(:debug)
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    handler.call("data: {\"x\":1}\n\n", 0, env)

    expect(RubyLLM.logger).to have_received(:debug).at_least(:once)
  end

  it 'raises the error an SSE error event carries' do
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    expect do
      handler.call("event: error\ndata: {\"error\":{\"message\":\"Rate limit exceeded\"}}\n\n", 0, env)
    end.to raise_error(RubyLLM::ServerError, /Rate limit exceeded/)
  end

  it 'ignores an error event that is not valid JSON' do
    allow(RubyLLM.logger).to receive(:debug)
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    expect { handler.call("event: error\ndata: broken\n\n", 0, env) }.not_to raise_error
    expect(RubyLLM.logger).to have_received(:debug)
  end

  it 'ignores a data chunk that is not valid JSON' do
    allow(RubyLLM.logger).to receive(:debug)
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    expect { handler.call("data: {broken\n\n", 0, env) }.not_to raise_error
    expect(RubyLLM.logger).to have_received(:debug)
  end

  it 'stops at the DONE sentinel without yielding' do
    yielded = []
    handler = test_obj.send(:handle_stream) { |chunk| yielded << chunk }

    handler.call("data: [DONE]\n\n", 0, env)

    expect(yielded).to eq([])
  end

  it 'accumulates a failed response body until it parses' do
    allow(RubyLLM.logger).to receive(:debug)
    failed_env = Faraday::Env.from(status: 500)
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    expect { handler.call('{"error":{"message":', 0, failed_env) }.not_to raise_error
    expect do
      handler.call('"Rate limit exceeded"}}', 0, failed_env)
    end.to raise_error(RubyLLM::ServerError, /Rate limit exceeded/)
  end

  it 'reports an unknown streaming error when the payload names none' do
    allow(RubyLLM.logger).to receive(:debug)
    handler = test_obj.send(:handle_stream) { |_chunk| nil }

    expect do
      handler.call("data: {\"error\":{}}\n\n", 0, env)
    end.to raise_error(RubyLLM::Error)
  end
end
