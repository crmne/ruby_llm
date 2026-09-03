# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Streaming do
  let(:protocol) { RubyLLM::Protocols::ChatCompletions.allocate }

  it 'splits thinking chunk deltas from content deltas' do
    thinking_chunk = protocol.send(
      :build_chunk,
      {
        'model' => 'mistral-small-latest',
        'choices' => [
          {
            'delta' => {
              'content' => [
                { 'type' => 'thinking', 'thinking' => [{ 'type' => 'text', 'text' => 'pondering' }], 'closed' => true },
                { 'type' => 'text', 'text' => 'Four' }
              ]
            }
          }
        ]
      }
    )

    expect(thinking_chunk.thinking.text).to eq('pondering')
    expect(thinking_chunk.content).to eq('Four')

    text_chunk = protocol.send(
      :build_chunk,
      {
        'model' => 'mistral-small-latest',
        'choices' => [{ 'delta' => { 'content' => ' and more' } }]
      }
    )

    expect(text_chunk.thinking).to be_nil
    expect(text_chunk.content).to eq(' and more')
  end

  it 'preserves raw finish reasons on chunks' do
    chunk = protocol.send(
      :build_chunk,
      {
        'model' => 'gpt-4.1-nano',
        'choices' => [
          {
            'delta' => { 'content' => '' },
            'finish_reason' => 'tool_calls'
          }
        ]
      }
    )

    expect(chunk.finish_reason).to eq(:tool_calls)
  end

  describe '#parse_streaming_error' do
    it 'parses typed error objects' do
      status, message = protocol.send(
        :parse_streaming_error,
        { error: { type: 'rate_limit_exceeded', message: 'Slow down' } }.to_json
      )

      expect(status).to eq(429)
      expect(message).to eq('Slow down')
    end

    it 'reports a 500 for server errors' do
      status, message = protocol.send(
        :parse_streaming_error,
        { error: { type: 'server_error', message: 'Internal error' } }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('Internal error')
    end

    it 'falls back to a 400 for other typed error objects' do
      status, message = protocol.send(
        :parse_streaming_error,
        { error: { type: 'invalid_request_error', message: 'Bad request' } }.to_json
      )

      expect(status).to eq(400)
      expect(message).to eq('Bad request')
    end

    it 'handles a body that parses to a bare JSON string' do
      status, message = protocol.send(
        :parse_streaming_error,
        '"The model foo is not available in your region (error)."'
      )

      expect(status).to be_nil
      expect(message).to eq('The model foo is not available in your region (error).')
    end

    it 'handles a string error value' do
      status, message = protocol.send(
        :parse_streaming_error,
        { error: 'The model foo is not available in your region.' }.to_json
      )

      expect(status).to be_nil
      expect(message).to eq('The model foo is not available in your region.')
    end
  end

  it 'surfaces the provider message for a failed streaming response with a string error value' do
    provider = instance_double(RubyLLM::Providers::OpenAI)
    allow(provider).to receive(:parse_error) { |response| response.body['error'] }
    protocol.instance_variable_set(:@provider, provider)
    failed_env = Faraday::Env.from(status: 404)

    expect do
      protocol.send(
        :handle_failed_response,
        '{"error": "The model foo is not available in your region."}',
        +'',
        failed_env
      )
    end.to raise_error(RubyLLM::Error, /not available in your region/)
  end
end
