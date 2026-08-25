# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Chat do
  include_context 'with configured RubyLLM'

  # Create a test object that includes the module to access private methods
  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Protocols::Gemini::Media)
      obj.extend(RubyLLM::Protocols::Gemini::Tools)
      obj.extend(described_class)
    end
  end

  describe '#render_payload' do
    let(:messages) { [] }
    let(:tools) { {} }
    let(:schema) do
      {
        name: 'response',
        schema: {
          type: 'object',
          properties: {
            result: { type: 'string' }
          }
        },
        strict: true
      }
    end

    it 'renders system messages as systemInstruction' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.5-flash', family: nil, metadata: {})
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hi'),
        RubyLLM::Message.new(role: :system, content: 'Be brief.')
      ]

      payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema: nil)

      expect(payload[:systemInstruction]).to eq(parts: [{ text: 'Be brief.' }])
      expect(payload[:contents].map { |message| message[:role] }).to eq(['user'])
    end

    it 'sends responseJsonSchema whatever the model is named' do
      %w[gemini-2.5-flash gemini-flash-latest gemini-pro-latest gemini-flash-lite-latest gemini-3.6-flash].each do |id|
        model = instance_double(RubyLLM::Model, id:, family: nil, metadata: {})

        payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema:)

        expect(payload[:generationConfig][:responseJsonSchema]).to eq(
          'type' => 'object',
          'properties' => {
            'result' => { 'type' => 'string' }
          }
        )
        expect(payload[:generationConfig]).not_to have_key(:responseSchema)
        expect(payload[:generationConfig]).not_to have_key('responseSchema')
      end
    end

    it 'strips strict, which Gemini has no field for' do
      model = instance_double(RubyLLM::Model, id: 'gemini-flash-latest', family: nil, metadata: {})
      wrapped_schema = {
        name: 'PersonSchema',
        schema: {
          type: 'object',
          properties: {
            result: { type: 'string' }
          },
          strict: true
        }
      }

      payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema: wrapped_schema)

      expect(payload[:generationConfig][:responseJsonSchema]).to eq(
        'type' => 'object',
        'properties' => {
          'result' => { 'type' => 'string' }
        }
      )
    end

    it 'keeps the JSON Schema keywords the old conversion dropped' do
      model = instance_double(RubyLLM::Model, id: 'gemini-flash-latest', family: nil, metadata: {})
      rich_schema = {
        name: 'contact',
        schema: {
          type: 'object',
          additionalProperties: false,
          '$defs' => { 'Tag' => { type: 'string' } },
          properties: {
            name: { type: 'string', pattern: '^[A-Z][a-z]+$', minLength: 2 },
            kind: { const: 'person' },
            contact: { anyOf: [{ type: 'string', format: 'email' }, { type: 'integer', minimum: 1 }] },
            tags: { type: 'array', items: { '$ref' => '#/$defs/Tag' }, default: [] }
          },
          required: %w[name kind contact]
        }
      }

      rendered = test_obj.send(
        :render_payload, messages, tools:, temperature: nil, model:, schema: rich_schema
      )[:generationConfig][:responseJsonSchema]

      expect(rendered['additionalProperties']).to be(false)
      expect(rendered['$defs']).to eq('Tag' => { 'type' => 'string' })
      expect(rendered['properties']['name']).to eq(
        'type' => 'string', 'pattern' => '^[A-Z][a-z]+$', 'minLength' => 2
      )
      expect(rendered['properties']['kind']).to eq('const' => 'person')
      expect(rendered['properties']['contact']['anyOf'].length).to eq(2)
      expect(rendered['properties']['tags']['items']).to eq('$ref' => '#/$defs/Tag')
      expect(rendered['properties']['tags']['default']).to eq([])
    end
  end

  describe '#render_count_tokens_payload' do
    it 'wraps the request in generateContentRequest without generationConfig' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.5-flash', family: nil, metadata: {})
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Be terse.'),
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]

      payload = test_obj.send(:render_count_tokens_payload, messages, tools: {}, model: model)

      request = payload[:generateContentRequest]
      expect(request[:model]).to eq('models/gemini-2.5-flash')
      expect(request[:contents]).to eq([{ role: 'user', parts: [{ text: 'Hello' }] }])
      expect(request[:systemInstruction]).to eq(parts: [{ text: 'Be terse.' }])
      expect(request).not_to have_key(:generationConfig)
    end
  end

  describe '#parse_count_tokens_response' do
    it 'reads totalTokens' do
      response = instance_double(Faraday::Response, body: { 'totalTokens' => 42 })

      expect(test_obj.send(:parse_count_tokens_response, response)).to eq(42)
    end
  end

  describe '#format_messages' do
    it 'groups consecutive tool responses into a single user message with multiple function responses' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Question?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          tool_calls: {
            'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}),
            'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'best_language_to_learn', arguments: {})
          }
        ),
        RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1'),
        RubyLLM::Message.new(role: :tool, content: 'Ruby', tool_call_id: 'call_2')
      ]

      result = test_obj.send(:format_messages, messages)

      expect(result.length).to eq(3)
      tool_response = result.last
      expect(tool_response[:role]).to eq('user')
      expect(tool_response[:parts].length).to eq(2)
      expect(tool_response[:parts][0][:functionResponse][:name]).to eq('weather')
      expect(tool_response[:parts][1][:functionResponse][:name]).to eq('best_language_to_learn')
    end

    it 'restores call order when results of the same tool finish out of order' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Question?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          tool_calls: {
            'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: { city: 'Berlin' }),
            'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'weather', arguments: { city: 'Paris' })
          }
        ),
        RubyLLM::Message.new(role: :tool, content: 'Paris is sunny', tool_call_id: 'call_2'),
        RubyLLM::Message.new(role: :tool, content: 'Berlin is rainy', tool_call_id: 'call_1')
      ]

      parts = test_obj.send(:format_messages, messages).last[:parts]

      expect(parts.map { |part| part[:functionResponse][:response][:content] }).to eq(
        [[{ text: 'Berlin is rainy' }], [{ text: 'Paris is sunny' }]]
      )
    end

    it 'does not send finish_reason back to the provider' do
      messages = [RubyLLM::Message.new(role: :assistant, content: 'Done', finish_reason: 'max_tokens')]

      result = test_obj.send(:format_messages, messages)

      expect(result.first).not_to have_key(:finishReason)
      expect(result.first[:parts]).to eq([{ text: 'Done' }])
    end
  end

  describe '#warn_unsupported_citations' do
    it 'warns when citations are asked of a model that does not support them' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.5-flash', supports?: false, metadata: {}, family: nil)
      allow(RubyLLM.logger).to receive(:warn)

      test_obj.send(
        :render_payload, [], tools: [], temperature: nil, model: model, citations: true
      )

      expect(RubyLLM.logger).to have_received(:warn).with(/does not support citations/)
    end
  end

  describe '#build_thinking_config' do
    it 'sends the effort level when one is set' do
      thinking = RubyLLM::Thinking::Config.new(effort: :high)

      expect(test_obj.send(:build_thinking_config, nil, thinking)).to eq(
        includeThoughts: true, thinkingLevel: 'high'
      )
    end

    it 'sends a numeric budget when one is set' do
      thinking = RubyLLM::Thinking::Config.new(budget: 1024)

      expect(test_obj.send(:build_thinking_config, nil, thinking)).to eq(
        includeThoughts: true, thinkingBudget: 1024
      )
    end
  end

  describe '#format_role' do
    it 'maps assistant to model and the rest to user' do
      expect(test_obj.send(:format_role, :assistant)).to eq('model')
      expect(test_obj.send(:format_role, :system)).to eq('user')
      expect(test_obj.send(:format_role, :tool)).to eq('user')
      expect(test_obj.send(:format_role, :user)).to eq('user')
    end
  end

  describe '#format_system_instruction' do
    it 'skips empty system messages' do
      messages = [RubyLLM::Message.new(role: :system, content: '')]

      expect(test_obj.send(:format_system_instruction, messages)).to be_nil
    end
  end

  describe '#build_thought_part' do
    it 'omits the fields the provider did not send' do
      expect(test_obj.send(:build_thought_part, RubyLLM::Thinking.new(text: 'why'))).to eq(
        thought: true, text: 'why'
      )
      expect(test_obj.send(:build_thought_part, RubyLLM::Thinking.new(signature: 'sig'))).to eq(
        thought: true, thoughtSignature: 'sig'
      )
    end
  end

  describe '#extract_citations' do
    it 'returns nothing without grounding metadata' do
      expect(test_obj.send(:extract_citations, {}, 'text')).to eq([])
    end

    it 'cites every grounding chunk when there are no supports' do
      data = {
        'candidates' => [
          {
            'groundingMetadata' => {
              'groundingChunks' => [
                { 'web' => { 'uri' => 'https://a.example', 'title' => 'A' } },
                { 'retrievedContext' => { 'uri' => 'https://b.example', 'title' => 'B' } },
                { 'unknown' => {} },
                'not a chunk'
              ]
            }
          }
        ]
      }

      citations = test_obj.send(:extract_citations, data, 'text')

      expect(citations.map(&:url)).to eq(['https://a.example', 'https://b.example'])
      expect(citations.map(&:source_index)).to eq([0, 1])
    end

    it 'anchors supports to character offsets in the response text' do
      data = {
        'candidates' => [
          {
            'groundingMetadata' => {
              'groundingChunks' => [{ 'web' => { 'uri' => 'https://a.example', 'title' => 'A' } }],
              'groundingSupports' => [
                { 'segment' => { 'endIndex' => 4, 'text' => 'Café' }, 'groundingChunkIndices' => [0, 9] }
              ]
            }
          }
        ]
      }

      citations = test_obj.send(:extract_citations, data, 'Café is French')

      expect(citations.length).to eq(1)
      expect(citations.first.start_index).to eq(0)
      expect(citations.first.end_index).to eq(4)
    end

    it 'leaves offsets nil when the support carries no segment' do
      data = {
        'candidates' => [
          {
            'groundingMetadata' => {
              'groundingChunks' => [{ 'web' => { 'uri' => 'https://a.example' } }],
              'groundingSupports' => [{ 'groundingChunkIndices' => [0] }]
            }
          }
        ]
      }

      citation = test_obj.send(:extract_citations, data, 'text').first

      expect(citation.start_index).to be_nil
      expect(citation.end_index).to be_nil
    end
  end

  describe '#parse_content' do
    it 'returns empty content for a response with no candidate' do
      expect(test_obj.send(:parse_content, {})).to eq(['', []])
    end

    it 'returns empty content for a candidate with no parts' do
      expect(test_obj.send(:parse_content, { 'candidates' => [{ 'content' => {} }] })).to eq(['', []])
    end
  end

  describe '#extract_thought_signature' do
    it 'reads the signature off a function call part' do
      parts = [{ 'functionCall' => { 'thought_signature' => 'sig' } }]

      expect(test_obj.send(:extract_thought_signature, parts)).to eq('sig')
    end

    it 'returns nil when no part carries one' do
      expect(test_obj.send(:extract_thought_signature, [{ 'text' => 'hi' }])).to be_nil
    end
  end

  describe '#parse_completion_response' do
    it 'preserves raw finishReason' do
      response = instance_double(
        Faraday::Response,
        body: {
          'candidates' => [
            {
              'finishReason' => 'SAFETY',
              'content' => { 'parts' => [{ 'text' => 'No' }] }
            }
          ]
        }
      )

      provider = RubyLLM::Protocols::Gemini.allocate
      message = provider.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq('SAFETY')
    end

    it 'keeps thought-only parts out of assistant content' do
      response = Struct.new(:body, :env).new(
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'thought' => true, 'text' => 'Internal reasoning only' }
                ]
              }
            }
          ],
          'usageMetadata' => {}
        },
        Struct.new(:url).new(Struct.new(:path).new('/v1/models/gemini-2.5-flash:generateContent'))
      )

      provider = RubyLLM::Protocols::Gemini.allocate
      message = provider.send(:parse_completion_response, response)

      expect(message.content).to eq('')
      expect(message.thinking&.text).to eq('Internal reasoning only')
    end

    it 'keeps non-thought text in content when mixed with thought parts' do
      response = Struct.new(:body, :env).new(
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'thought' => true, 'text' => 'Reasoning trace' },
                  { 'text' => '{"ok":true}' }
                ]
              }
            }
          ],
          'usageMetadata' => {}
        },
        Struct.new(:url).new(Struct.new(:path).new('/v1/models/gemini-2.5-flash:generateContent'))
      )

      provider = RubyLLM::Protocols::Gemini.allocate
      message = provider.send(:parse_completion_response, response)

      expect(message.content).to eq('{"ok":true}')
      expect(message.thinking&.text).to eq('Reasoning trace')
    end

    it 'captures cached token usage when present' do
      response = Struct.new(:body, :env).new(
        {
          'candidates' => [
            {
              'content' => {
                'parts' => [{ 'text' => 'Hi' }]
              }
            }
          ],
          'usageMetadata' => {
            'promptTokenCount' => 42,
            'candidatesTokenCount' => 8,
            'cachedContentTokenCount' => 21
          }
        },
        Struct.new(:url).new(Struct.new(:path).new('/v1/models/gemini-2.5-flash:generateContent'))
      )

      provider = RubyLLM::Protocols::Gemini.allocate
      message = provider.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(21)
      expect(message.tokens.output).to eq(8)
      expect(message.tokens.cache_read).to eq(21)
    end
  end
end
