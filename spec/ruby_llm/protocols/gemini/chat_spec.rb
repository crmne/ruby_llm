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

  describe '#convert_schema_to_gemini' do
    it 'extracts inner schema from wrapper format' do
      # Simulate what RubyLLM::Schema.to_json_schema returns
      schema = {
        name: 'PersonSchema',
        schema: {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer' }
          }
        }
      }

      result = test_obj.send(:convert_schema_to_gemini, schema)

      # Should extract the inner schema and convert it
      expect(result[:type]).to eq('OBJECT')
      expect(result[:properties][:name][:type]).to eq('STRING')
      expect(result[:properties][:age][:type]).to eq('INTEGER')
    end

    it 'converts simple string schema' do
      schema = { type: 'string' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts string schema with enum' do
      schema = { type: 'string', enum: %w[red green blue] }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING', enum: %w[red green blue] })
    end

    it 'converts string schema with format' do
      schema = { type: 'string', format: 'email' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING', format: 'email' })
    end

    it 'converts number schema' do
      schema = { type: 'number' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'NUMBER' })
    end

    it 'converts number schema with constraints' do
      schema = {
        type: 'number',
        minimum: 0,
        maximum: 100,
        format: 'float'
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'NUMBER',
                             format: 'float',
                             minimum: 0,
                             maximum: 100
                           })
    end

    it 'converts integer schema' do
      schema = { type: 'integer' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'INTEGER' })
    end

    it 'converts boolean schema' do
      schema = { type: 'boolean' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'BOOLEAN' })
    end

    it 'converts array schema' do
      schema = {
        type: 'array',
        items: { type: 'string' }
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'STRING' }
                           })
    end

    it 'converts array schema with constraints' do
      schema = {
        type: 'array',
        items: { type: 'integer' },
        minItems: 1,
        maxItems: 10
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'INTEGER' },
                             minItems: 1,
                             maxItems: 10
                           })
    end

    it 'converts array schema without items to default STRING' do
      schema = { type: 'array' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'ARRAY',
                             items: { type: 'STRING' }
                           })
    end

    it 'converts object schema' do
      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        required: %w[name]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'OBJECT',
                             properties: {
                               name: { type: 'STRING' },
                               age: { type: 'INTEGER' }
                             },
                             required: %w[name]
                           })
    end

    it 'converts object schema with propertyOrdering' do
      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        propertyOrdering: %w[name age]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to include(propertyOrdering: %w[name age])
    end

    it 'handles nullable fields' do
      schema = {
        type: 'string',
        nullable: true
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             nullable: true
                           })
    end

    it 'handles descriptions' do
      schema = {
        type: 'string',
        description: 'A user name'
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             description: 'A user name'
                           })
    end

    it 'converts nested object schemas' do
      schema = {
        type: 'object',
        properties: {
          user: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              contacts: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    type: { type: 'string', enum: %w[email phone] },
                    value: { type: 'string' }
                  }
                }
              }
            }
          }
        }
      }

      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result[:type]).to eq('OBJECT')
      expect(result[:properties][:user][:type]).to eq('OBJECT')
      expect(result[:properties][:user][:properties][:name][:type]).to eq('STRING')
      expect(result[:properties][:user][:properties][:contacts][:type]).to eq('ARRAY')
      expect(result[:properties][:user][:properties][:contacts][:items][:type]).to eq('OBJECT')
      expect(result[:properties][:user][:properties][:contacts][:items][:properties][:type][:enum]).to eq(%w[email
                                                                                                             phone])
    end

    it 'handles nil schema' do
      result = test_obj.send(:convert_schema_to_gemini, nil)
      expect(result).to be_nil
    end

    it 'converts schemas provided with string keys' do
      schema = {
        'type' => 'object',
        'properties' => {
          'status' => {
            'anyOf' => [
              {
                'type' => 'string',
                'enum' => %w[pending done],
                'description' => 'Current status value'
              },
              { 'type' => 'null' }
            ]
          },
          'count' => {
            'type' => 'integer',
            'minimum' => 0
          }
        },
        'required' => %w[status count],
        'propertyOrdering' => %w[status count],
        'nullable' => false
      }

      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'OBJECT',
                             properties: {
                               status: {
                                 type: 'STRING',
                                 enum: %w[pending done],
                                 nullable: true,
                                 description: 'Current status value'
                               },
                               count: {
                                 type: 'INTEGER',
                                 minimum: 0
                               }
                             },
                             required: %w[status count],
                             propertyOrdering: %w[status count],
                             nullable: false
                           })
    end

    it 'expands $ref definitions in array items' do
      schema = {
        type: 'object',
        properties: {
          answers: {
            type: 'array',
            items: { '$ref' => '#/$defs/answer' }
          }
        },
        required: %w[answers],
        '$defs' => {
          'answer' => {
            type: 'object',
            properties: {
              score: { type: 'integer' }
            },
            required: %w[score]
          }
        }
      }

      result = test_obj.send(:convert_schema_to_gemini, schema)

      answers_schema = result[:properties][:answers]
      expect(answers_schema[:type]).to eq('ARRAY')
      expect(answers_schema[:items]).to eq(
        type: 'OBJECT',
        properties: {
          score: { type: 'INTEGER' }
        },
        required: %w[score]
      )
    end

    it 'defaults unknown types to STRING' do
      schema = { type: 'unknown' }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts anyOf with null to nullable' do
      schema = {
        anyOf: [
          { type: 'string', format: 'email' },
          { type: 'null' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             format: 'email',
                             nullable: true
                           })
    end

    it 'converts anyOf with multiple non-null types by choosing first' do
      schema = {
        anyOf: [
          { type: 'string' },
          { type: 'integer' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({ type: 'STRING' })
    end

    it 'converts anyOf with only null to nullable string' do
      schema = {
        anyOf: [
          { type: 'null' }
        ]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result).to eq({
                             type: 'STRING',
                             nullable: true
                           })
    end

    it 'converts complex schema with anyOf in properties' do
      schema = {
        type: 'object',
        properties: {
          email: {
            anyOf: [
              { type: 'string', format: 'email' },
              { type: 'null' }
            ]
          },
          name: { type: 'string' }
        },
        required: %w[name]
      }
      result = test_obj.send(:convert_schema_to_gemini, schema)

      expect(result[:type]).to eq('OBJECT')
      expect(result[:properties][:email]).to eq({
                                                  type: 'STRING',
                                                  format: 'email',
                                                  nullable: true
                                                })
      expect(result[:properties][:name]).to eq({ type: 'STRING' })
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

    it 'uses responseJsonSchema for Gemini 2.5 models' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.5-flash', family: nil, metadata: {})

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

    it 'unwraps wrapper schemas for responseJsonSchema' do
      model = instance_double(RubyLLM::Model, id: 'gemini-3.0-pro', family: nil, metadata: {})
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

    it 'falls back to responseSchema for non-2.5 models' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.0-flash', family: nil, metadata: {})

      payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema:)

      expect(payload[:generationConfig][:responseSchema]).to include(type: 'OBJECT')
      expect(payload[:generationConfig]).not_to have_key(:responseJsonSchema)
      expect(payload[:generationConfig]).not_to have_key('responseJsonSchema')
    end

    it 'treats newer Gemini versions as JSON schema capable' do
      model = instance_double(RubyLLM::Model, id: 'gemini-3.0-pro', family: nil, metadata: {})

      payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema:)

      expect(payload[:generationConfig]).to include(:responseJsonSchema)
      expect(payload[:generationConfig]).not_to have_key(:responseSchema)
    end

    it 'expands referenced definitions when using responseSchema' do
      model = instance_double(RubyLLM::Model, id: 'gemini-2.0-flash', family: nil, metadata: {})
      schema_with_defs = {
        type: 'object',
        properties: {
          answers: {
            type: 'array',
            items: { '$ref' => '#/$defs/answer' }
          }
        },
        '$defs' => {
          'answer' => {
            type: 'object',
            properties: {
              score: { type: 'integer' }
            },
            required: %w[score]
          }
        }
      }

      payload = test_obj.send(:render_payload, messages, tools:, temperature: nil, model:, schema: schema_with_defs)

      items_schema = payload[:generationConfig][:responseSchema][:properties][:answers][:items]
      expect(items_schema).to eq(
        type: 'OBJECT',
        properties: {
          score: { type: 'INTEGER' }
        },
        required: %w[score]
      )
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

  describe '#gemini_version' do
    it 'is nil without a model' do
      expect(test_obj.send(:gemini_version, nil)).to be_nil
    end

    it 'is nil when nothing in the model names a version' do
      model = instance_double(RubyLLM::Model, id: 'gemini-flash', family: nil, metadata: {})

      expect(test_obj.send(:gemini_version, model)).to be_nil
    end

    it 'falls back to the model metadata' do
      model = instance_double(RubyLLM::Model, id: 'gemini-flash', family: nil, metadata: { version: '2.5' })

      expect(test_obj.send(:gemini_version, model)).to eq(Gem::Version.new('2.5'))
    end
  end

  describe '#extract_version' do
    it 'is nil for text without a version' do
      expect(test_obj.send(:extract_version, nil)).to be_nil
      expect(test_obj.send(:extract_version, 'flash')).to be_nil
    end
  end

  describe RubyLLM::Protocols::Gemini::Chat::GeminiSchema do
    def convert(schema)
      described_class.new(schema).to_h
    end

    it 'returns nothing for a nil schema' do
      expect(convert(nil)).to be_nil
    end

    it 'falls back to a string schema for a non-object node' do
      expect(convert({ type: 'object', properties: { name: 'nonsense' } })[:properties][:name]).to eq(type: 'STRING')
    end

    it 'reads definitions from the legacy definitions key' do
      schema = {
        type: 'object',
        definitions: { Name: { type: 'string' } },
        properties: { name: { '$ref' => '#/definitions/Name' } }
      }

      expect(convert(schema)[:properties][:name]).to eq(type: 'STRING')
    end

    it 'merges definitions found at more than one level' do
      schema = {
        type: 'object',
        '$defs' => { Outer: { type: 'string' } },
        properties: {
          nested: {
            type: 'object',
            definitions: { Inner: { type: 'integer' } },
            properties: {
              outer: { '$ref' => '#/$defs/Outer' },
              inner: { '$ref' => '#/$defs/Inner' }
            }
          }
        }
      }

      nested = convert(schema)[:properties][:nested][:properties]

      expect(nested[:outer]).to eq(type: 'STRING')
      expect(nested[:inner]).to eq(type: 'INTEGER')
    end

    it 'ignores an empty definitions block' do
      expect(convert({ type: 'object', '$defs' => nil, properties: {} })[:type]).to eq('OBJECT')
    end

    it 'falls back to a string schema for an unresolvable reference' do
      schema = { type: 'object', properties: { name: { '$ref' => '#/$defs/Missing' } } }

      expect(convert(schema)[:properties][:name]).to eq(type: 'STRING')
    end

    it 'stops at a self-referential definition' do
      schema = {
        type: 'object',
        '$defs' => {
          Node: {
            type: 'object',
            properties: { child: { '$ref' => '#/$defs/Node' } }
          }
        },
        properties: { root: { '$ref' => '#/$defs/Node' } }
      }

      root = convert(schema)[:properties][:root]

      expect(root[:type]).to eq('OBJECT')
      expect(root[:properties][:child]).to eq(type: 'STRING')
    end

    it 'handles a reference that names no path' do
      schema = { type: 'object', properties: { name: { '$ref' => '' } } }

      expect(convert(schema)[:properties][:name]).to eq(type: 'STRING')
    end

    it 'stops walking a definition path through a non-object' do
      schema = {
        type: 'object',
        '$defs' => { Name: { type: 'string' } },
        properties: { name: { '$ref' => '#/$defs/Name/deeper' } }
      }

      expect(convert(schema)[:properties][:name]).to eq(type: 'STRING')
    end

    it 'keeps the sibling keys of an anyOf' do
      schema = {
        type: 'object',
        properties: {
          name: { description: 'a name', anyOf: [{ type: 'string' }, { type: 'null' }] }
        }
      }

      expect(convert(schema)[:properties][:name]).to eq(
        type: 'STRING', nullable: true, description: 'a name'
      )
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
