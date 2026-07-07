# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Chat do
  describe '.parse_completion_body' do
    it 'exposes AWS inputTokens as-is (already non-cached) and keeps cache buckets separate' do
      # Per AWS, inputTokens already excludes cache; a real payload sends the non-cached count
      # directly, with cache read/write reported separately.
      response_body = {
        'modelId' => 'anthropic.claude-sonnet-4-5-20250929-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 50,
          'outputTokens' => 5,
          'cacheReadInputTokens' => 40,
          'cacheWriteInputTokens' => 10
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.input_tokens).to eq(50)
      expect(message.output_tokens).to eq(5)
      expect(message.cache_read_tokens).to eq(40)
      expect(message.cache_write_tokens).to eq(10)
    end

    it 'does not subtract cache buckets or floor to zero when the cached prefix exceeds fresh input' do
      response_body = {
        'modelId' => 'anthropic.claude-sonnet-4-5-20250929-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 3,
          'outputTokens' => 5,
          'cacheReadInputTokens' => 7714,
          'cacheWriteInputTokens' => 327
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.input_tokens).to eq(3)
      expect(message.cache_read_tokens).to eq(7714)
      expect(message.cache_write_tokens).to eq(327)
    end

    it 'preserves raw stopReason as finish_reason' do
      response_body = {
        'modelId' => 'amazon.nova-lite-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'stopReason' => 'guardrail_intervened',
        'usage' => {}
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.finish_reason).to eq('guardrail_intervened')
    end

    it 'falls back to the request model when Bedrock omits modelId' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {}
      }

      provider = double(config: RubyLLM.config, connection: nil)
      model = instance_double(RubyLLM::Model, id: 'openai.gpt-oss-120b-1:0')
      protocol = RubyLLM::Protocols::Converse.new(provider, model)
      response = instance_double(Faraday::Response, body: response_body)
      message = protocol.send(:parse_completion_body, response_body, raw: response)

      expect(message.model).to eq('openai.gpt-oss-120b-1:0')
    end

    it 'extracts thinking tokens from top-level reasoningTokens' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'reasoningTokens' => 7
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.thinking_tokens).to eq(7)
    end

    it 'extracts thinking tokens from outputTokensDetails reasoningTokens' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'outputTokensDetails' => { 'reasoningTokens' => 7 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.thinking_tokens).to eq(7)
    end
  end

  describe '.format_tool_result_content' do
    it 'uses a placeholder when the tool returns no content' do
      msg = instance_double(RubyLLM::Message, content: '', attachments: [])
      result = described_class.format_tool_result_content(msg)

      expect(result).to eq([{ text: '(no output)' }])
    end
  end

  describe '.render_payload' do
    let(:model) do
      instance_double(RubyLLM::Model,
                      id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                      max_output_tokens: nil,
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

    it 'appends cachePoint to a system message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here!

      payload = render_payload([message, RubyLLM::Message.new(role: :user, content: 'Hi')])

      expect(payload[:system].last).to eq(cachePoint: { type: 'default' })
    end

    it 'appends cachePoint to a user message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      payload = render_payload([message])

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default' })
    end

    it 'uses configured ttl for an explicit cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      payload = render_payload([message], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
    end

    it 'adds an automatic cachePoint to the last cacheable message when caching is enabled' do
      first = RubyLLM::Message.new(role: :user, content: 'Stable context')
      second = RubyLLM::Message.new(role: :user, content: 'Latest question')

      payload = render_payload([first, second], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).not_to have_key(:cachePoint)
      expect(payload.dig(:messages, 1, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
    end

    it 'does not add automatic cachePoint when an explicit boundary exists' do
      first = RubyLLM::Message.new(role: :user, content: 'Stable context').cache_until_here!
      second = RubyLLM::Message.new(role: :user, content: 'Latest question')

      payload = render_payload([first, second], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
      expect(payload.dig(:messages, 1, :content).last).not_to have_key(:cachePoint)
    end

    it 'rejects caching options it cannot render' do
      expect do
        render_payload(caching: { retention: '24h' })
      end.to raise_error(ArgumentError, /Bedrock Converse prompt caching accepts :ttl/)
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

    it 'does not send finish_reason back to the provider' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Done', finish_reason: 'MAX_TOKENS')

      payload = render_payload([message], schema: nil)

      expect(payload[:messages].first).not_to have_key(:finishReason)
      expect(payload[:messages].first[:content]).to eq([{ text: 'Done' }])
    end
  end
end
