# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  describe '.render_payload' do
    let(:model) do
      instance_double(RubyLLM::Model::Info,
                      id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                      max_tokens: nil,
                      metadata: {})
    end

    let(:base_args) do
      {
        tools: {},
        temperature: nil,
        model: model,
        stream: false
      }
    end

    def render_payload(messages = [], **overrides)
      described_class.render_payload(messages, **base_args, **overrides)
    end

    context 'when schema is provided' do
      let(:schema) do
        {
          name: 'response',
          schema: {
            type: 'object',
            properties: { name: { type: 'string' } },
            required: ['name'],
            additionalProperties: false
          },
          strict: true
        }
      end

      it 'includes outputConfig with stringified schema' do
        payload = render_payload(schema: schema)

        output_config = payload[:outputConfig]
        expect(output_config).not_to be_nil
        expect(output_config[:textFormat][:type]).to eq('json_schema')

        json_schema = output_config[:textFormat][:structure][:jsonSchema]
        expect(json_schema[:name]).to eq('response')
        expect(json_schema[:schema]).to be_a(String)

        parsed = JSON.parse(json_schema[:schema])
        expect(parsed['type']).to eq('object')
        expect(parsed['properties']).to eq({ 'name' => { 'type' => 'string' } })
      end

      it 'strips :strict from the schema' do
        payload = render_payload(schema: schema)

        json_schema = payload[:outputConfig][:textFormat][:structure][:jsonSchema]
        parsed = JSON.parse(json_schema[:schema])
        expect(parsed).not_to have_key('strict')
        expect(parsed).not_to have_key(:strict)
      end

      it 'uses schema name and inner schema' do
        custom_schema = RubyLLM::Utils.deep_dup(schema)
        custom_schema[:name] = 'PersonSchema'

        payload = render_payload(schema: custom_schema)

        json_schema = payload[:outputConfig][:textFormat][:structure][:jsonSchema]
        expect(json_schema[:name]).to eq('PersonSchema')

        parsed = JSON.parse(json_schema[:schema])
        expect(parsed['type']).to eq('object')
        expect(parsed['properties']).to eq({ 'name' => { 'type' => 'string' } })
        expect(parsed).not_to have_key('name')
        expect(parsed).not_to have_key('schema')
      end

      it 'does not mutate the original schema' do
        original = RubyLLM::Utils.deep_dup(schema)
        render_payload(schema: schema)
        expect(schema).to eq(original)
      end
    end

    context 'when schema is nil' do
      it 'does not include outputConfig' do
        payload = render_payload(schema: nil)
        expect(payload).not_to have_key(:outputConfig)
      end
    end
  end

  describe '.parse_completion_response' do
    it 'extracts thinking_tokens from top-level reasoningTokens' do
      response_body = {
        'output' => { 'message' => { 'content' => [{ 'text' => 'Hi!' }] } },
        'usage' => {
          'inputTokens' => 100,
          'outputTokens' => 50,
          'reasoningTokens' => 1200
        }
      }
      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_response(response)

      expect(message.thinking_tokens).to eq(1200)
    end

    it 'extracts thinking_tokens from nested outputTokensDetails' do
      response_body = {
        'output' => { 'message' => { 'content' => [{ 'text' => 'Hi!' }] } },
        'usage' => {
          'inputTokens' => 100,
          'outputTokens' => 50,
          'outputTokensDetails' => { 'reasoningTokens' => 800 }
        }
      }
      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_response(response)

      expect(message.thinking_tokens).to eq(800)
    end

    it 'captures cache usage metrics' do
      response_body = {
        'output' => { 'message' => { 'content' => [{ 'text' => 'Hi!' }] } },
        'usage' => {
          'inputTokens' => 100,
          'outputTokens' => 50,
          'cacheReadInputTokens' => 30,
          'cacheWriteInputTokens' => 10
        }
      }
      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_response(response)

      expect(message.input_tokens).to eq(100)
      expect(message.output_tokens).to eq(50)
      expect(message.cached_tokens).to eq(30)
      expect(message.cache_creation_tokens).to eq(10)
    end
  end
end
