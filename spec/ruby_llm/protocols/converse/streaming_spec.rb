# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Streaming do
  let(:streaming) do
    Object.new.tap do |object|
      object.extend(described_class)
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model, id: 'bedrock-test-model'))
      object.define_singleton_method(:escape_model_id) { |id| id.to_s.gsub('/', '%2F') }
      object.define_singleton_method(:parse_error) { |response| response.body['message'] }
    end
  end

  it 'extracts thinking text from Bedrock Converse Stream reasoningContent deltas' do
    event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'text' => 'thinking text'
          }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.thinking.text).to eq('thinking text')
  end

  it 'extracts thinking signatures from Bedrock Converse Stream reasoningContent deltas' do
    event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'signature' => 'thinking-signature'
          }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.thinking.signature).to eq('thinking-signature')
  end

  it 'preserves raw stopReason from messageStop events' do
    event = {
      'messageStop' => {
        'stopReason' => 'max_tokens'
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.finish_reason).to eq('max_tokens')
  end

  it 'extracts thinking tokens from nested usage output token details' do
    event = {
      'metadata' => {
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'outputTokensDetails' => { 'reasoningTokens' => 7 }
        }
      }
    }

    chunk = streaming.send(:build_chunk, event)

    expect(chunk.tokens.thinking).to eq(7)
  end

  it 'accumulates Bedrock Converse Stream thinking deltas into the final message' do
    accumulator = RubyLLM::StreamAccumulator.new
    text_event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'text' => 'thinking text'
          }
        }
      }
    }
    signature_event = {
      'contentBlockDelta' => {
        'delta' => {
          'reasoningContent' => {
            'signature' => 'thinking-signature'
          }
        }
      }
    }

    accumulator.add(streaming.send(:build_chunk, text_event))
    accumulator.add(streaming.send(:build_chunk, signature_event))
    message = accumulator.to_message(nil)

    expect(message.thinking.text).to eq('thinking text')
    expect(message.thinking.signature).to eq('thinking-signature')
  end

  describe '#stream_url' do
    it 'escapes the model id into the converse-stream path' do
      expect(streaming.send(:stream_url)).to eq('/model/bedrock-test-model/converse-stream')
    end
  end

  describe 'error events' do
    it 'raises the mapped error for each Bedrock exception frame' do
      {
        'throttlingException' => RubyLLM::RateLimitError,
        'validationException' => RubyLLM::BadRequestError,
        'accessDeniedException' => RubyLLM::UnauthorizedError,
        'unrecognizedClientException' => RubyLLM::UnauthorizedError,
        'serviceUnavailableException' => RubyLLM::ServiceUnavailableError,
        'internalServerException' => RubyLLM::ServerError
      }.each do |key, error_class|
        expect do
          streaming.send(:build_chunk, { key => { 'message' => 'nope' } })
        end.to raise_error(error_class, /nope/)
      end
    end

    it 'falls back to the exception name when the frame carries no message' do
      expect do
        streaming.send(:build_chunk, { 'validationException' => {} })
      end.to raise_error(RubyLLM::BadRequestError, /validationException/)
    end

    it 'raises for a typed error event' do
      expect do
        streaming.send(:build_chunk, { 'type' => 'error', 'error' => { 'message' => 'stream broke' } })
      end.to raise_error(RubyLLM::ServerError, /stream broke/)
    end

    it 'uses a default message for a typed error event with no detail' do
      expect do
        streaming.send(:build_chunk, { 'type' => 'error' })
      end.to raise_error(RubyLLM::ServerError, /Bedrock streaming error/)
    end
  end

  describe '#handle_non_eventstream_error_chunk' do
    it 'raises on an SSE error frame' do
      chunk = "event: error\ndata: {\"message\":\"stream broke\"}\n\n"

      expect { streaming.send(:handle_non_eventstream_error_chunk, chunk) }.to raise_error(
        RubyLLM::ServerError, /stream broke/
      )
    end

    it 'ignores an SSE error frame with no data line' do
      expect { streaming.send(:handle_non_eventstream_error_chunk, "event: error\n\n") }.not_to raise_error
    end

    it 'raises on a bare JSON error body' do
      expect do
        streaming.send(:handle_non_eventstream_error_chunk, '{"error":{"message":"stream broke"}}')
      end.to raise_error(RubyLLM::ServerError, /stream broke/)
    end

    it 'ignores an ordinary binary frame' do
      expect { streaming.send(:handle_non_eventstream_error_chunk, "\x00\x01event") }.not_to raise_error
    end

    it 'ignores an error frame that is not valid JSON' do
      expect { streaming.send(:handle_non_eventstream_error_chunk, '{"error": broken') }.not_to raise_error
    end
  end

  describe '#handle_failed_stream' do
    it 'ignores a chunk that is not valid JSON' do
      expect { streaming.send(:handle_failed_stream, 'not json', {}) }.not_to raise_error
    end

    it 'raises the parsed error' do
      env = Faraday::Env.from(status: 403)

      expect do
        streaming.send(:handle_failed_stream, '{"message":"denied"}', env)
      end.to raise_error(RubyLLM::ForbiddenError, /denied/)
    end
  end

  describe '#decode_event_payload' do
    it 'unwraps a base64 bytes envelope' do
      payload = { 'bytes' => Base64.strict_encode64({ 'contentBlockDelta' => {} }.to_json) }.to_json

      expect(streaming.send(:decode_event_payload, payload)).to eq('contentBlockDelta' => {})
    end

    it 'returns nil for an undecodable payload' do
      allow(RubyLLM.logger).to receive(:debug)

      expect(streaming.send(:decode_event_payload, 'not json')).to be_nil
    end
  end

  describe '#decode_events' do
    it 'logs the event keys when stream debugging is on' do
      decoder = Object.new
      frames = [[Struct.new(:payload).new(StringIO.new({ 'messageStop' => {} }.to_json)), true]]
      decoder.define_singleton_method(:decode_chunk) { |_chunk = nil| frames.shift }
      allow(RubyLLM.config).to receive(:log_stream_debug).and_return(true)
      allow(RubyLLM.logger).to receive(:debug)

      events = streaming.send(:decode_events, decoder, 'frame')

      expect(events).to eq([{ 'messageStop' => {} }])
      expect(RubyLLM.logger).to have_received(:debug)
    end
  end

  describe 'thinking signatures on content block starts' do
    it 'reads the signature out of reasoningText' do
      event = {
        'contentBlockStart' => {
          'start' => { 'reasoningContent' => { 'reasoningText' => { 'signature' => 'sig' } } }
        }
      }

      expect(streaming.send(:build_chunk, event).thinking.signature).to eq('sig')
    end

    it 'falls back to redacted content' do
      event = {
        'contentBlockStart' => { 'start' => { 'reasoningContent' => { 'redactedContent' => 'redacted' } } }
      }

      expect(streaming.send(:build_chunk, event).thinking.signature).to eq('redacted')
    end

    it 'reports no signature when the start carries neither' do
      event = { 'contentBlockStart' => { 'start' => { 'reasoningContent' => {} } } }

      expect(streaming.send(:build_chunk, event).thinking).to be_nil
    end
  end

  describe 'tool call frames' do
    it 'reads a tool call out of a content block start' do
      event = {
        'contentBlockStart' => {
          'start' => { 'toolUse' => { 'toolUseId' => 'call_1', 'name' => 'lookup' } }
        }
      }

      tool_calls = streaming.send(:build_chunk, event).tool_calls

      expect(tool_calls['call_1'].name).to eq('lookup')
      expect(tool_calls['call_1'].arguments).to eq({})
    end

    it 'reads argument fragments out of a delta' do
      event = { 'contentBlockDelta' => { 'delta' => { 'toolUse' => { 'input' => '{"q":' } } } }

      expect(streaming.send(:build_chunk, event).tool_calls[nil].arguments).to eq('{"q":')
    end

    it 'reports no tool calls for a start frame without a toolUse' do
      event = { 'contentBlockStart' => { 'start' => {} } }

      expect(streaming.send(:build_chunk, event).tool_calls).to be_nil
    end
  end

  describe '#normalized_delta' do
    it 'parses a JSON string delta' do
      expect(streaming.send(:normalized_delta, { 'delta' => '{"text":"hi"}' })).to eq('text' => 'hi')
    end

    it 'treats an empty string delta as no delta' do
      expect(streaming.send(:normalized_delta, { 'delta' => '' })).to eq({})
    end

    it 'treats an unparseable string delta as no delta' do
      expect(streaming.send(:normalized_delta, { 'delta' => '{broken' })).to eq({})
    end
  end

  describe 'on_data routing in stream_response' do
    # Captures the on_data proc that stream_response installs on the Faraday
    # request, by faking @connection/@provider/req just enough to run the block.
    let(:captured_on_data) do
      captured = nil
      request_options = Object.new
      request_options.define_singleton_method(:on_data=) { |proc| captured = proc }
      req = Object.new
      req.define_singleton_method(:headers) { {} }
      req.define_singleton_method(:options) { request_options }

      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:post) do |_url, _payload, &block|
        block.call(req)
        nil
      end

      provider = double('provider', sign_headers: {}) # rubocop:disable RSpec/VerifiedDoubles

      streaming.instance_variable_set(:@connection, connection)
      streaming.instance_variable_set(:@provider, provider)
      allow(streaming).to receive_messages(event_stream_decoder: :decoder, parse_stream_chunk: nil,
                                           handle_failed_stream: nil)
      allow(RubyLLM::StreamAccumulator).to receive(:new).and_return(
        instance_double(RubyLLM::StreamAccumulator, to_message: RubyLLM::Message.new(role: :assistant, content: ''))
      )

      streaming.send(:stream_response, {})
      captured
    end

    before { stub_const('Faraday::VERSION', '2.0.0') }

    # Faraday 2 with the net_http adapter passes a nil env during streaming
    # (status unknown). Chunks must still be parsed, not dropped as failures.
    it 'parses the chunk when env is nil (status not yet known)' do
      captured_on_data.call('event-frame', 11, nil)

      expect(streaming).to have_received(:parse_stream_chunk).with(:decoder, 'event-frame', anything)
      expect(streaming).not_to have_received(:handle_failed_stream)
    end

    it 'parses the chunk when env reports a 200 status' do
      env = Struct.new(:status).new(200)
      captured_on_data.call('event-frame', 11, env)

      expect(streaming).to have_received(:parse_stream_chunk).with(:decoder, 'event-frame', anything)
      expect(streaming).not_to have_received(:handle_failed_stream)
    end

    it 'routes the chunk to failure handling when env reports a non-200 status' do
      env = Struct.new(:status).new(403)
      captured_on_data.call('error-frame', 11, env)

      expect(streaming).to have_received(:handle_failed_stream).with('error-frame', env)
      expect(streaming).not_to have_received(:parse_stream_chunk)
    end
  end
end
