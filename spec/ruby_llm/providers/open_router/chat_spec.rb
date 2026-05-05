# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Chat do
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'anthropic/claude-haiku-4.5') }

  describe '.render_payload' do
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    before do
      allow(described_class).to receive(:format_messages).and_return([{ role: 'user', content: 'Hello' }])
    end

    it 'uses canonical wrapped schema payload' do
      schema = {
        name: 'response',
        schema: {
          type: 'object',
          properties: {
            answer: { type: 'string' }
          }
        },
        strict: true
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
      expect(payload[:response_format][:json_schema][:strict]).to be(true)
    end

    it 'uses wrapper schema name and inner schema' do
      schema = {
        name: 'PersonSchema',
        schema: {
          type: 'object',
          properties: {
            name: { type: 'string' }
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
        schema: schema
      )

      expect(payload[:response_format][:json_schema][:name]).to eq('PersonSchema')
      expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
      expect(payload[:response_format][:json_schema][:strict]).to be(false)
    end
  end

  describe '.parse_completion_response' do
    let(:response) { instance_double(Faraday::Response, body: nil) }

    it "doesn't throw an error when response is nil" do
      expect { described_class.parse_completion_response(response) }.not_to raise_error
    end
  end
end
