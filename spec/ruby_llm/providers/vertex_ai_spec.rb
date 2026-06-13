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
      faraday_adapter: :net_http,
      vertexai_location: location,
      vertexai_project_id: 'test-project',
      vertexai_api_base: vertexai_api_base,
      vertexai_protocol: nil
    )
  end

  let(:vertexai_api_base) { nil }

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

    context 'when vertexai_api_base is set' do
      let(:location) { 'us-central1' }
      let(:vertexai_api_base) { 'https://vertex-proxy.example.com/v1beta1' }

      it 'uses the custom API URL' do
        expect(provider.api_base).to eq('https://vertex-proxy.example.com/v1beta1')
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

      protocol = RubyLLM::Providers::VertexAI::Gemini.new(provider, model)
      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload.dig(:contents, 2, :role)).to eq('user')
      expect(payload.dig(:contents, 2, :parts, 0, :functionResponse, :name)).to eq('weather')
    end
  end

  describe '#protocol_for' do
    let(:location) { 'us-east5' }

    it 'routes claude models to the Anthropic protocol' do
      model = instance_double(RubyLLM::Model::Info, id: 'claude-haiku-4-5@20251001')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::Anthropic)
    end

    it 'routes google models to the Gemini protocol' do
      model = instance_double(RubyLLM::Model::Info, id: 'gemini-2.5-flash')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::Gemini)
    end
  end

  describe 'Anthropic protocol dialect' do
    let(:location) { 'us-east5' }
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-haiku-4-5@20251001', max_tokens: 4096) }
    let(:protocol) { RubyLLM::Providers::VertexAI::Anthropic.new(provider, model) }

    it 'speaks to rawPredict under the anthropic publisher' do
      expect(protocol.send(:completion_url)).to eq(
        'projects/test-project/locations/us-east5/publishers/anthropic/models/claude-haiku-4-5@20251001:rawPredict'
      )
      expect(protocol.send(:stream_url)).to eq(
        'projects/test-project/locations/us-east5/publishers/anthropic/models/' \
        'claude-haiku-4-5@20251001:streamRawPredict'
      )
    end

    it 'swaps the model key for anthropic_version' do
      messages = [RubyLLM::Message.new(role: :user, content: 'hi')]

      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload[:model]).to be_nil
      expect(payload[:anthropic_version]).to eq('vertex-2023-10-16')
      expect(payload.dig(:messages, 0, :role)).to eq('user')
    end
  end
end
