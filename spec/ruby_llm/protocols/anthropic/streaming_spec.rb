# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Streaming do
  include_context 'with configured RubyLLM'

  let(:protocol) do
    RubyLLM::Protocols::Anthropic.allocate.tap do |object|
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model, id: 'claude-sonnet-4-5'))
    end
  end

  it 'preserves raw stop_reason from message_delta events' do
    chunk = protocol.send(
      :build_chunk,
      {
        'type' => 'message_delta',
        'delta' => { 'stop_reason' => 'end_turn' },
        'usage' => { 'output_tokens' => 10 }
      }
    )

    expect(chunk.finish_reason).to eq('end_turn')
  end

  it 'reads thinking token counts from message_delta usage' do
    chunk = protocol.send(
      :build_chunk,
      {
        'type' => 'message_delta',
        'delta' => { 'stop_reason' => 'end_turn' },
        'usage' => { 'output_tokens' => 10, 'output_tokens_details' => { 'thinking_tokens' => 7 } }
      }
    )

    expect(chunk.tokens.thinking).to eq(7)
  end

  it 'sends Accept-Encoding: identity on streaming requests' do
    captured = nil

    stub_request(:post, %r{api\.anthropic\.com/v1/messages})
      .with { |req| captured = req.headers['Accept-Encoding'] }
      .to_return(
        status: 200,
        body: '',
        headers: { 'Content-Type' => 'text/event-stream' }
      )

    chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
    chat.ask('hi') { |_chunk| nil }

    expect(captured).to eq('identity')
  end

  describe '#parse_streaming_error' do
    it 'parses typed error objects' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: { type: 'overloaded_error', message: 'Overloaded' } }.to_json
      )

      expect(status).to eq(529)
      expect(message).to eq('Overloaded')
    end

    it 'falls back to a 500 for other typed error objects' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: { type: 'invalid_request_error', message: 'Bad request' } }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('Bad request')
    end

    it 'handles a string error value' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: 'Overloaded' }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('Overloaded')
    end

    it 'ignores a body that parses to a bare JSON string' do
      expect(protocol.send(:parse_streaming_error, '"model unavailable (type: error)"')).to be_nil
    end
  end
end
