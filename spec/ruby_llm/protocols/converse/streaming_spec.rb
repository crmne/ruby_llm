# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Streaming do
  let(:streaming) do
    Object.new.tap do |object|
      object.extend(described_class)
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model::Info, id: 'bedrock-test-model'))
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
