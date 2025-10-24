# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Chat do
  describe '.parse_completion_response' do
    it 'captures cached token information when present' do
      response_body = {
        'model' => 'gpt-4.1-nano',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 8,
          'completion_tokens' => 4,
          'prompt_tokens_details' => { 'cached_tokens' => 6 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_response(response)

      expect(message.cached_tokens).to eq(6)
      expect(message.input_tokens).to eq(8)
      expect(message.output_tokens).to eq(4)
      expect(message.cache_creation_tokens).to eq(0)
    end
  end

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-4o') }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    before do
      allow(described_class).to receive(:format_messages).and_return([{ role: 'user', content: 'Hello' }])
    end

    context 'with schema' do
      it 'defaults schema name to "response" for plain schema' do
        schema = {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer' }
          }
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:name]).to eq('response')
        expect(payload[:response_format][:json_schema][:schema]).to eq(schema)
        expect(payload[:response_format][:json_schema][:strict]).to be(true)
      end

      it 'uses custom schema name when provided in full format' do
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

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:name]).to eq('PersonSchema')
        expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
        expect(payload[:response_format][:json_schema][:strict]).to be(true)
      end

      it 'respects explicit strict: false for both formats' do
        # Full format with strict: false
        schema_full = {
          name: 'PersonSchema',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'integer' }
            }
          },
          strict: false
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema_full
        )

        expect(payload[:response_format][:json_schema][:strict]).to be(false)

        # Plain format with strict: false
        schema_plain = {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer' }
          },
          strict: false
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema_plain
        )

        expect(payload[:response_format][:json_schema][:strict]).to be(false)
      end
    end
  end
end
