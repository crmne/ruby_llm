# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      vertexai_location: location,
      vertexai_project_id: 'test-project'
    )
  end

  describe '#api_base' do
    context 'when location is global' do
      let(:location) { 'global' }

      it 'uses the correct api_base without location prefix' do
        expect(provider.api_base).to eq('https://aiplatform.googleapis.com/v1beta1')
      end
    end

    context 'when location is not global' do
      let(:location) { 'us-central1' }

      it 'uses the correct api_base with location prefix' do
        expect(provider.api_base).to eq('https://us-central1-aiplatform.googleapis.com/v1beta1')
      end
    end
  end

  describe '#render_payload' do
    let(:location) { 'us-central1' }
    let(:model) do
      instance_double(RubyLLM::Model::Info, id: 'gemini-2.5-pro', max_tokens: nil, metadata: {})
    end

    it 'normalizes tool response content roles to user' do
      tool_message = instance_double(
        RubyLLM::Message,
        role: :tool,
        tool_call_id: 'call_1',
        content: 'tool output'
      )
      user_message = instance_double(
        RubyLLM::Message,
        role: :user,
        tool_call?: false,
        tool_result?: false,
        content: 'prompt'
      )

      payload = provider.send(:render_payload, [tool_message, user_message], tools: {}, temperature: nil, model: model)

      expect(payload[:contents]).to eq(
        [
          {
            role: 'user',
            parts: [
              {
                functionResponse: {
                  name: 'call_1',
                  response: {
                    name: 'call_1',
                    content: [{ text: 'tool output' }]
                  }
                }
              }
            ]
          },
          { role: 'user', parts: [{ text: 'prompt' }] }
        ]
      )
    end
  end
end
