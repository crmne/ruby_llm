# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Streaming do
  let(:protocol) { RubyLLM::Protocols::ChatCompletions.allocate }

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

    expect(chunk.finish_reason).to eq('tool_calls')
  end

  describe '#parse_streaming_error' do
    it 'classifies server errors as 500' do
      data = { 'error' => { 'type' => 'server_error', 'message' => 'The server had an error' } }.to_json

      expect(protocol.send(:parse_streaming_error, data)).to eq([500, 'The server had an error'])
    end

    it 'classifies rate limit errors as 429' do
      data = { 'error' => { 'type' => 'rate_limit_exceeded', 'message' => 'Rate limit reached' } }.to_json

      expect(protocol.send(:parse_streaming_error, data)).to eq([429, 'Rate limit reached'])
    end

    it 'classifies other typed errors as 400' do
      data = { 'error' => { 'type' => 'invalid_request_error', 'message' => 'Bad request' } }.to_json

      expect(protocol.send(:parse_streaming_error, data)).to eq([400, 'Bad request'])
    end

    it 'returns nil when the body has no error key' do
      data = { 'choices' => [] }.to_json

      expect(protocol.send(:parse_streaming_error, data)).to be_nil
    end

    it 'handles a string-valued error without raising' do
      data = { 'error' => 'The model foo is not available in your region.' }.to_json

      expect(protocol.send(:parse_streaming_error, data))
        .to eq([500, 'The model foo is not available in your region.'])
    end

    it 'returns nil when the body parses to a JSON string mentioning an error' do
      data = 'The upstream provider returned an error.'.to_json

      expect(protocol.send(:parse_streaming_error, data)).to be_nil
    end
  end
end
