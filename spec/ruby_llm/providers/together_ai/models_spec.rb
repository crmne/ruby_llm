# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TogetherAI::Models do
  describe '.models_url' do
    it 'returns the correct models endpoint' do
      expect(described_class.models_url).to eq('models')
    end
  end

  describe '.parse_list_models_response' do
    let(:slug) { 'together' }
    let(:capabilities) { RubyLLM::Providers::TogetherAI::Capabilities }

    let(:response_body) do
      {
        'data' => [
          {
            'id' => 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
            'object' => 'model',
            'created' => 1_234_567_890,
            'owned_by' => 'Meta'
          },
          {
            'id' => 'Qwen/Qwen2.5-72B-Instruct-Turbo',
            'object' => 'model',
            'created' => 1_234_567_891,
            'owned_by' => 'Alibaba'
          }
        ]
      }
    end

    let(:response) { instance_double(Faraday::Response, body: response_body) }

    before do
      allow(capabilities).to receive_messages(format_display_name: 'Display Name', model_family: 'llama',
                                              context_window_for: 8192, max_tokens_for: 4096,
                                              modalities_for: { input: ['text'], output: ['text'] },
                                              capabilities_for: ['chat'],
                                              pricing_for: { input_tokens: 0.001, output_tokens: 0.002 })
    end

    it 'parses model information correctly' do
      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.length).to eq(2)

      first_model = models.first
      expect(first_model.id).to eq('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(first_model.provider).to eq('together')
      expect(first_model.created_at).to eq(Time.at(1_234_567_890))
      expect(first_model.metadata[:object]).to eq('model')
      expect(first_model.metadata[:owned_by]).to eq('Meta')
    end

    it 'handles empty response data' do
      empty_response = instance_double(Faraday::Response, body: { 'data' => [] })

      models = described_class.parse_list_models_response(empty_response, slug, capabilities)

      expect(models).to be_empty
    end

    it 'handles response with no data key' do
      no_data_response = instance_double(Faraday::Response, body: {})

      models = described_class.parse_list_models_response(no_data_response, slug, capabilities)

      expect(models).to be_empty
    end

    it 'calls capabilities methods with correct parameters' do
      described_class.parse_list_models_response(response, slug, capabilities)

      expect(capabilities).to have_received(:format_display_name).with('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(capabilities).to have_received(:model_family).with('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(capabilities).to have_received(:context_window_for).with('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(capabilities).to have_received(:max_tokens_for).with('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
    end
  end
end
