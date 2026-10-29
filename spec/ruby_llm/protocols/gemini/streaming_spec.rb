# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Streaming do
  include_context 'with configured RubyLLM'

  let(:test_obj) { RubyLLM::Protocols::Gemini.allocate }

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

  it 'carries a generated image on the chunk that delivers it' do
    image = Base64.strict_encode64('image')
    data = {
      'candidates' => [{
        'content' => { 'parts' => [{ 'inlineData' => { 'mimeType' => 'image/png', 'data' => image } }] },
        'finishReason' => 'STOP'
      }]
    }

    chunk = test_obj.send(:build_chunk, data)

    expect(chunk.attachments.map(&:filename)).to eq(['gemini_attachment_1.png'])
    expect(chunk.attachments.first.content).to eq('image')
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

  it 'places streamed citations in the text streamed so far' do
    grounding = { 'groundingChunks' => [{ 'web' => { 'uri' => 'https://ruby-lang.org', 'title' => 'Ruby' } }],
                  'groundingSupports' => [{ 'segment' => { 'startIndex' => 17, 'endIndex' => 36,
                                                           'text' => 'It dates from 1995.' },
                                            'groundingChunkIndices' => [0] }] }
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    [{ 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Matz créa Ruby. ' }] } }] },
     { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'It dates from 1995.' }] },
                          'finishReason' => 'STOP', 'groundingMetadata' => grounding }] }].each do |event|
      accumulator.add(test_obj.send(:build_chunk, event))
    end
    message = accumulator.to_message(nil)

    expect(message.citations.map(&:to_h)).to eq(
      [{ url: 'https://ruby-lang.org', title: 'Ruby', text: 'It dates from 1995.',
         start_index: 16, end_index: 35, source_index: 0 }]
    )
    expect(message.content[16...35]).to eq('It dates from 1995.')
  end

  it 'continues the last text part across events without losing earlier part boundaries' do
    first = { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => '前言。Ruby' }, { 'text' => '甲😀Ru' }] } }] }
    final = { 'candidates' => [{
      'content' => { 'parts' => [{ 'text' => 'by' }] }, 'finishReason' => 'STOP',
      'groundingMetadata' => {
        'groundingChunks' => [{ 'web' => { 'uri' => 'https://ruby-lang.org' } }],
        'groundingSupports' => [{ 'segment' => { 'partIndex' => 1, 'startIndex' => '甲😀'.bytesize,
                                                 'endIndex' => '甲😀Ruby'.bytesize, 'text' => 'Ruby' },
                                  'groundingChunkIndices' => [0] }]
      }
    }] }
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    [first, final].each { |event| accumulator.add(test_obj.send(:build_chunk, event)) }
    message = accumulator.to_message(nil)
    citation = message.citations.first

    expect(message.content).to eq('前言。Ruby甲😀Ruby')
    expect([citation.start_index, citation.end_index]).to eq([9, 13])
    expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
    expect(first.dig('candidates', 0, 'content', 'parts', 1, 'text')).to eq('甲😀Ru')
  end

  it 'keeps thinking and media parts separate from continued visible text' do
    events = [
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'hidden', 'thought' => true }] } }] },
      { 'candidates' => [{ 'content' => { 'parts' => [
        { 'text' => ' thought', 'thought' => true }, { 'text' => '前言。', 'thought' => false },
        { 'inlineData' => { 'mimeType' => 'image/png', 'data' => Base64.strict_encode64('image') } }, { 'text' => 'Ru' }
      ] } }] },
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'by', 'thought' => false }] },
                           'finishReason' => 'STOP', 'groundingMetadata' => {
                             'groundingChunks' => [{ 'web' => { 'uri' => 'https://ruby-lang.org' } }],
                             'groundingSupports' => [{ 'segment' => { 'partIndex' => 3, 'endIndex' => 4,
                                                                      'text' => 'Ruby' },
                                                       'groundingChunkIndices' => [0] }]
                           } }] }
    ]
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    events.each { |event| accumulator.add(test_obj.send(:build_chunk, event)) }
    message = accumulator.to_message(nil)
    citation = message.citations.first

    expect(message.content).to eq('前言。Ruby')
    expect([citation.start_index, citation.end_index]).to eq([3, 7])
    expect(message.content[citation.start_index...citation.end_index]).to eq('Ruby')
  end

  it 'starts a visible part when a thinking fragment ends in an earlier event' do
    test_obj.send(:build_chunk, { 'candidates' => [{
                    'content' => { 'parts' => [{ 'text' => 'hidden', 'thought' => true }] }
                  }] })
    chunk = test_obj.send(:build_chunk, { 'candidates' => [{
                            'content' => { 'parts' => [{ 'text' => 'Ruby' }] }, 'finishReason' => 'STOP',
                            'groundingMetadata' => {
                              'groundingChunks' => [{ 'web' => { 'uri' => 'https://ruby-lang.org' } }],
                              'groundingSupports' => [{ 'segment' => { 'partIndex' => 1, 'endIndex' => 4,
                                                                       'text' => 'Ruby' },
                                                        'groundingChunkIndices' => [0] }]
                            }
                          }] })

    expect(chunk.content).to eq('Ruby')
    expect(chunk.citations.map { |citation| [citation.start_index, citation.end_index] }).to eq([[0, 4]])
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

  it 'signs a streamed agentic video answer with its own signature, not a navigation step' do
    navigation = [
      { 'thoughtSignature' => 'sig_A', 'toolCall' => { 'id' => 'call_1' } },
      { 'thoughtSignature' => 'sig_B', 'toolResponse' => { 'id' => 'call_1' } }
    ]
    navigation_chunks = navigation.map do |part|
      test_obj.send(:build_chunk, { 'candidates' => [{ 'content' => { 'parts' => [part] } }] })
    end
    chunk = test_obj.send(:build_chunk, {
                            'candidates' => [{
                              'content' => { 'parts' => [{ 'text' => 'Waves roll onto a beach.',
                                                           'thoughtSignature' => 'sig_E' }] },
                              'finishReason' => 'STOP'
                            }],
                            'usageMetadata' => { 'promptTokenCount' => 300, 'candidatesTokenCount' => 9,
                                                 'toolUsePromptTokenCount' => 1200 }
                          })

    expect(navigation_chunks.map(&:thinking)).to all(be_nil)
    expect(chunk.thinking.signature).to eq('sig_E')
    expect(chunk.raw_content).to be_nil
    expect(chunk.tokens.input).to eq(1500)
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
