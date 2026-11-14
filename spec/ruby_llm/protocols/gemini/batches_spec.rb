# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Batches do
  let(:protocol) { RubyLLM::Providers::Gemini.protocols.fetch(:gemini).allocate }

  describe '#gemini_batch_request' do
    it 'wraps rendered GenerateContent payloads with model and metadata' do
      request = {
        custom_id: '0',
        model: 'gemini-2.5-flash',
        payload: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }]
        }
      }

      formatted = protocol.send(:gemini_batch_request, request, 'gemini-2.5-flash')

      expect(formatted).to eq(
        request: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }],
          model: 'models/gemini-2.5-flash'
        },
        metadata: {
          custom_id: '0'
        }
      )
    end

    it 'sends structured output as responseSchema, which batchGenerateContent honors' do
      request = {
        custom_id: '0',
        model: 'gemini-2.5-flash',
        payload: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: {
              '$schema': 'https://json-schema.org/draft/2020-12/schema',
              type: 'object',
              properties: {
                title: { type: 'string', description: 'Headline' },
                score: { type: %w[integer null] },
                tags: { type: 'array', items: { type: 'string' } }
              },
              required: %w[title tags],
              additionalProperties: false
            }
          }
        }
      }

      config = protocol.send(:gemini_batch_request, request, 'gemini-2.5-flash').dig(:request, :generationConfig)

      expect(config).not_to have_key(:responseJsonSchema)
      expect(config[:responseSchema]).to eq(
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Headline' },
          score: { type: 'integer', nullable: true },
          tags: { type: 'array', items: { type: 'string' } }
        },
        required: %w[title tags]
      )
    end

    it 'keeps each non-null member of a nullable type union regardless of order' do
      [%w[string integer null], %w[null integer string]].each do |types|
        schema = { 'type' => types, 'description' => 'An identifier', 'nullable' => false }

        expect(render_batch_schema(schema)).to match(
          anyOf: contain_exactly(
            { 'type' => 'string', 'description' => 'An identifier' },
            { 'type' => 'integer', 'description' => 'An identifier' }
          ),
          nullable: true
        )
      end
    end

    it 'puts annotations and enums only on the branches that can carry them' do
      schema = { type: %w[string number boolean], title: 'Value', enum: ['a', 1], format: 'float' }

      expect(render_batch_schema(schema)).to eq(
        anyOf: [
          { type: 'string', title: 'Value', enum: ['a', 1], format: 'float' },
          { type: 'number', title: 'Value', enum: ['a', 1], format: 'float' },
          { type: 'boolean', title: 'Value' }
        ]
      )
    end

    it 'puts type-specific constraints on the corresponding branches of a union' do
      schema = {
        type: %w[integer array],
        minimum: 1,
        items: { type: %w[string null] },
        minItems: 2
      }

      expect(render_batch_schema(schema)).to eq(
        anyOf: [
          { type: 'integer', minimum: 1 },
          { type: 'array', items: { type: 'string', nullable: true }, minItems: 2 }
        ]
      )
    end

    it 'renders a single-element type array as a scalar type' do
      %w[string null].each do |type|
        expect(render_batch_schema(type: [type])).to eq(type:)
      end
    end

    it 'preserves an explicit anyOf' do
      schema = { anyOf: [{ type: 'string' }, { type: 'integer' }] }

      expect(render_batch_schema(schema)).to eq(schema)
    end

    it 'does not rewrite literal objects that look like schema nodes' do
      example = { type: %w[string integer] }
      schema = { type: %w[string object], example: }

      expect(render_batch_schema(schema)).to eq(example:, anyOf: [{ type: 'string' }, { type: 'object' }])
    end

    it 'converts properties whose names match schema keywords' do
      schema = { type: 'object', properties: { strict: { type: 'boolean' }, example: { type: %w[string null] } } }

      expect(render_batch_schema(schema)).to eq(
        type: 'object',
        properties: { strict: { type: 'boolean' }, example: { type: 'string', nullable: true } }
      )
    end

    it 'rejects a type union combined with an explicit anyOf' do
      schema = { 'type' => %w[string integer], 'anyOf' => [{ 'type' => 'string' }] }

      expect { render_batch_schema(schema) }.to raise_error(ArgumentError, /type union and anyOf/)
    end

    def render_batch_schema(schema)
      request = {
        custom_id: '0',
        payload: { generationConfig: { responseJsonSchema: schema } }
      }
      protocol.send(:gemini_batch_request, request, 'gemini-2.5-flash')
              .dig(:request, :generationConfig, :responseSchema)
    end
  end

  describe '#create_batch' do
    it 'sends the converted union through the public batch API' do
      context = RubyLLM.context { |config| config.gemini_api_key = 'test-key' }
      chat = context.chat(model: 'gemini-2.5-flash', provider: :gemini)
      chat.with_schema(type: 'object', properties: { value: { type: %w[string integer null] } })
      chat.ask_later('Return an identifier.')
      request = stub_request(:post, %r{/v1beta/models/gemini-2\.5-flash:batchGenerateContent})
                .with do |http|
        config = JSON.parse(http.body).dig('batch', 'inputConfig', 'requests', 'requests', 0, 'request',
                                           'generationConfig')
        expect(config).not_to have_key('responseJsonSchema')
        expect(config.dig('responseSchema', 'properties', 'value')).to eq(
          'anyOf' => [{ 'type' => 'string' }, { 'type' => 'integer' }], 'nullable' => true
        )
      end.to_return_json(body: { name: 'batches/test', metadata: { state: 'BATCH_STATE_PENDING' } })

      RubyLLM.batch(chat)

      expect(request).to have_been_requested.once
    end

    it 'rejects mixed-model jobs' do
      requests = [
        { model: 'gemini-2.5-flash', payload: {} },
        { model: 'gemini-3-flash-preview', payload: {} }
      ]

      expect { protocol.create_batch(requests) }
        .to raise_error(RubyLLM::Error, /one model/)
    end
  end

  describe '#parse_batch_response' do
    it 'reads the state from the operation that create returns' do
      data = { 'name' => 'batches/abc', 'metadata' => { 'state' => 'JOB_STATE_PENDING' } }

      expect(protocol.send(:parse_batch_response, data)).to include(
        id: 'batches/abc', raw_status: 'JOB_STATE_PENDING', completed: false
      )
    end

    it 'reads the state from the batch that polling returns' do
      data = { 'name' => 'batches/abc', 'state' => 'BATCH_STATE_RUNNING', 'batchStats' => { 'requestCount' => '2' } }

      expect(protocol.send(:parse_batch_response, data)).to include(
        id: 'batches/abc', raw_status: 'BATCH_STATE_RUNNING', completed: false,
        request_counts: { 'requestCount' => '2' }, request_count: 2
      )
    end

    it 'marks terminal states completed regardless of the enum prefix' do
      states = %w[BATCH_STATE_SUCCEEDED JOB_STATE_SUCCEEDED JOB_STATE_FAILED JOB_STATE_CANCELLED JOB_STATE_EXPIRED]
      states.each do |state|
        expect(protocol.send(:parse_batch_response, 'name' => 'batches/abc', 'state' => state))
          .to include(completed: true)
      end
    end
  end

  describe '#parse_inline_response' do
    it 'parses a succeeded response keyed by the metadata custom id' do
      inline = {
        'metadata' => { 'custom_id' => '1' },
        'response' => {
          'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Jupiter' }] } }],
          'modelVersion' => 'gemini-2.5-flash',
          'usageMetadata' => { 'promptTokenCount' => 5, 'candidatesTokenCount' => 3 }
        }
      }

      index, message = protocol.send(:parse_inline_response, inline, 0)

      expect(index).to eq(1)
      expect(message.content).to eq('Jupiter')
      expect(message.model).to eq('gemini-2.5-flash')
      expect(message.tokens.input).to eq(5)
    end

    it 'falls back to the old metadata key and then position' do
      inline = { 'metadata' => { 'key' => '2' }, 'response' => { 'candidates' => [] } }
      expect(protocol.send(:parse_inline_response, inline, 0).first).to eq(2)

      inline = { 'response' => { 'candidates' => [] } }
      expect(protocol.send(:parse_inline_response, inline, 3).first).to eq(3)
    end

    it 'logs and skips a per-item error' do
      inline = { 'metadata' => { 'custom_id' => '0' }, 'error' => { 'code' => 400, 'message' => 'too long' } }
      allow(RubyLLM.logger).to receive(:warn)

      index, message = protocol.send(:parse_inline_response, inline, 0)

      expect(index).to eq(0)
      expect(message).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with(/failed: too long/)
    end
  end
end
