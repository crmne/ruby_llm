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

  it 'counts the web searches the final chunk grounds on' do
    text_chunk = test_obj.send(:build_chunk,
                               { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Ruby' }] } }] })
    final_chunk = test_obj.send(:build_chunk, {
                                  'candidates' => [{
                                    'content' => { 'parts' => [{ 'text' => ' 4.0.7' }] },
                                    'finishReason' => 'STOP',
                                    'groundingMetadata' => { 'webSearchQueries' => ['"Ruby 4.0.7" released'] }
                                  }],
                                  'usageMetadata' => { 'promptTokenCount' => 408, 'candidatesTokenCount' => 171 }
                                })

    expect(text_chunk.tokens.server_tool_use).to be_nil
    expect(final_chunk.tokens.server_tool_use).to eq('web_search_requests' => 1)
  end

  it 'streams the search suggestions on the live search call only' do
    suggestions = '<style>.container { display: flex; }</style><div class="container">Ruby 4.0.7</div>'
    chunk = test_obj.send(:build_chunk, {
                            'candidates' => [{
                              'content' => { 'parts' => [{ 'text' => 'Ruby 4.0.7' }] },
                              'finishReason' => 'STOP',
                              'groundingMetadata' => {
                                'searchEntryPoint' => { 'renderedContent' => suggestions },
                                'webSearchQueries' => ['"Ruby 4.0.7" released']
                              }
                            }]
                          })
    search = chunk.server_tool_calls.find { |call| call.type == 'google_search' }

    expect(search.search_suggestions).to eq(suggestions)
    expect(JSON.generate(search.to_h)).not_to include('container')
  end

  it 'drops search suggestions from the streamed parts it keeps for replay' do
    test_obj.send(:build_chunk, {
                    'candidates' => [{ 'content' => { 'parts' => [
                      { 'thoughtSignature' => 'sig-2',
                        'toolResponse' => { 'toolType' => 'GOOGLE_SEARCH_WEB', 'id' => 'call_1',
                                            'response' => { 'search_suggestions' => '<style></style>' } } },
                      { 'executableCode' => { 'language' => 'PYTHON', 'code' => 'print(4)' } }
                    ] } }]
                  })
    chunk = test_obj.send(:build_chunk, {
                            'candidates' => [{ 'content' => { 'parts' => [{ 'text' => '4' }] },
                                               'finishReason' => 'STOP' }]
                          })

    expect(chunk.raw_content.first.dig('toolResponse', 'response')).to eq({})
    expect(chunk.raw_content.size).to eq(3)
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

    expect(chunk.finish_reason).to eq(:max_tokens)
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
