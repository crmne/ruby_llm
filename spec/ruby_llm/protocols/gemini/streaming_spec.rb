# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Streaming do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Protocols::Gemini::Tools)
      obj.extend(RubyLLM::Protocols::Gemini::Chat)
      obj.extend(described_class)
    end
  end

  it 'captures cached token usage on chunks when present' do
    data = {
      'candidates' => [
        {
          'content' => {
            'parts' => [{ 'text' => 'hello' }]
          }
        }
      ],
      'usageMetadata' => {
        'promptTokenCount' => 10,
        'candidatesTokenCount' => 4,
        'cachedContentTokenCount' => 6
      },
      'modelVersion' => 'gemini-2.5-flash'
    }

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.tokens.input).to eq(4)
    expect(chunk.tokens.output).to eq(4)
    expect(chunk.tokens.cache_read).to eq(6)
  end

  it 'preserves raw finishReason on chunks' do
    data = {
      'candidates' => [
        {
          'finishReason' => 'MAX_TOKENS',
          'content' => { 'parts' => [{ 'text' => 'hello' }] }
        }
      ]
    }

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.finish_reason).to eq('MAX_TOKENS')
  end

  describe '#parse_streaming_error' do
    it 'parses error objects' do
      status, message = test_obj.send(
        :parse_streaming_error,
        { error: { code: 429, message: 'Quota exceeded' } }.to_json
      )

      expect(status).to eq(429)
      expect(message).to eq('Quota exceeded')
    end

    it 'handles a body that parses to a bare JSON string' do
      status, message = test_obj.send(:parse_streaming_error, '"model unavailable"')

      expect(status).to be_nil
      expect(message).to eq('model unavailable')
    end

    it 'handles a string error value' do
      status, message = test_obj.send(:parse_streaming_error, { error: 'model unavailable' }.to_json)

      expect(status).to be_nil
      expect(message).to eq('model unavailable')
    end
  end
end
