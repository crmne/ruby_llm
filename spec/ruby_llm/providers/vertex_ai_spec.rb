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

    it 'formats tool responses with a Vertex AI content role' do
      model = instance_double(RubyLLM::Model::Info, id: 'gemini-3.1-flash-lite-preview')
      messages = [
        RubyLLM::Message.new(role: :user, content: 'What is the weather?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          tool_calls: {
            'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
          }
        ),
        RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1')
      ]

      payload = provider.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload.dig(:contents, 2, :role)).to eq('user')
      expect(payload.dig(:contents, 2, :parts, 0, :functionResponse, :name)).to eq('weather')
    end
  end
end
