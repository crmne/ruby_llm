# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Chat do
  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-4o') }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    context 'with schema' do
      it 'uses custom schema name when provided in full format' do
        schema = {
          name: 'department_classification',
          schema: {
            type: 'object',
            properties: {
              department_id: { type: 'string' }
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

        expect(payload[:response_format][:json_schema][:name]).to eq('department_classification')
        expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
        expect(payload[:response_format][:json_schema][:strict]).to eq(true)
      end

      it 'defaults schema name to "response" for plain schema' do
        schema = {
          type: 'object',
          properties: {
            name: { type: 'string' }
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
        expect(payload[:response_format][:json_schema][:strict]).to eq(false)
      end

      it 'defaults schema name to "response" when full format has no name' do
        schema = {
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' }
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

        expect(payload[:response_format][:json_schema][:name]).to eq('response')
        expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
      end

      it 'respects strict: false when provided' do
        schema = {
          name: 'custom',
          schema: { type: 'object', properties: {} },
          strict: false
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:strict]).to eq(false)
      end

      it 'defaults strict to true when not specified in full format' do
        schema = {
          name: 'custom',
          schema: { type: 'object', properties: {} }
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:strict]).to eq(true)
      end
    end

    context 'without schema' do
      it 'does not include response_format' do
        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: nil
        )

        expect(payload).not_to have_key(:response_format)
      end
    end
  end
end
