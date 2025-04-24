# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Models do
  let(:slug) { 'bedrock' }
  let(:capabilities) { class_double(RubyLLM::Providers::Bedrock::Capabilities) }

  before do
    allow(capabilities).to receive_messages(
      context_window_for: 4096,
      max_tokens_for: 4096,
      model_type: :chat,
      model_family: :claude,
      supports_vision?: false,
      supports_functions?: false,
      supports_json_mode?: false,
      input_price_for: 0.0,
      output_price_for: 0.0,
      format_display_name: 'Test Model'
    )
  end

  describe '.create_model_info' do
    context 'when model supports INFERENCE_PROFILE only' do
      let(:model_data) do
        {
          'modelId' => 'anthropic.claude-3-7-sonnet-20250219-v1:0',
          'modelName' => 'Claude 3.7 Sonnet',
          'providerName' => 'Anthropic',
          'inferenceTypesSupported' => ['INFERENCE_PROFILE'],
          'inputModalities' => %w[TEXT IMAGE],
          'outputModalities' => ['TEXT'],
          'responseStreamingSupported' => true,
          'customizationsSupported' => []
        }
      end

      it 'adds us. prefix to model ID' do
        model_info = described_class.create_model_info(model_data, slug, capabilities)
        expect(model_info.id).to eq('us.anthropic.claude-3-7-sonnet-20250219-v1:0')
      end
    end

    context 'when model supports ON_DEMAND' do
      let(:model_data) do
        {
          'modelId' => 'anthropic.claude-3-5-sonnet-20240620-v1:0',
          'modelName' => 'Claude 3.5 Sonnet',
          'providerName' => 'Anthropic',
          'inferenceTypesSupported' => ['ON_DEMAND'],
          'inputModalities' => %w[TEXT IMAGE],
          'outputModalities' => ['TEXT'],
          'responseStreamingSupported' => true,
          'customizationsSupported' => []
        }
      end

      it 'does not add us. prefix to model ID' do
        model_info = described_class.create_model_info(model_data, slug, capabilities)
        expect(model_info.id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
      end
    end

    context 'when model supports both INFERENCE_PROFILE and ON_DEMAND' do
      let(:model_data) do
        {
          'modelId' => 'anthropic.claude-3-5-sonnet-20240620-v1:0',
          'modelName' => 'Claude 3.5 Sonnet',
          'providerName' => 'Anthropic',
          'inferenceTypesSupported' => %w[ON_DEMAND INFERENCE_PROFILE],
          'inputModalities' => %w[TEXT IMAGE],
          'outputModalities' => ['TEXT'],
          'responseStreamingSupported' => true,
          'customizationsSupported' => []
        }
      end

      it 'does not add us. prefix to model ID' do
        model_info = described_class.create_model_info(model_data, slug, capabilities)
        expect(model_info.id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
      end
    end

    context 'when inferenceTypesSupported is nil' do
      let(:model_data) do
        {
          'modelId' => 'anthropic.claude-3-5-sonnet-20240620-v1:0',
          'modelName' => 'Claude 3.5 Sonnet',
          'providerName' => 'Anthropic',
          'inputModalities' => %w[TEXT IMAGE],
          'outputModalities' => ['TEXT'],
          'responseStreamingSupported' => true,
          'customizationsSupported' => []
        }
      end

      it 'does not add us. prefix to model ID' do
        model_info = described_class.create_model_info(model_data, slug, capabilities)
        expect(model_info.id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
      end
    end
  end
end
