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
        # Mock a provider instance to test the region functionality
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('us-east-1')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)

        model_info = provider.send(:create_model_info, model_data, slug, capabilities)
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
        # Mock a provider instance to test the region functionality
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('us-east-1')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)

        model_info = provider.send(:create_model_info, model_data, slug, capabilities)
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
        # Mock a provider instance to test the region functionality
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('us-east-1')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)

        model_info = provider.send(:create_model_info, model_data, slug, capabilities)
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
        # Mock a provider instance to test the region functionality
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('us-east-1')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)

        model_info = provider.send(:create_model_info, model_data, slug, capabilities)
        expect(model_info.id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
      end
    end
  end

  # New specs for region-aware inference profile handling
  describe '#model_id_with_region with region awareness' do
    let(:provider_instance) do
      allow(RubyLLM.config).to receive(:bedrock_region).and_return('eu-west-3')
      provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
      provider.extend(described_class)
      provider
    end

    context 'with EU region configured' do
      let(:inference_profile_model) do
        {
          'modelId' => 'anthropic.claude-3-7-sonnet-20250219-v1:0',
          'inferenceTypesSupported' => ['INFERENCE_PROFILE']
        }
      end

      let(:us_prefixed_model) do
        {
          'modelId' => 'us.anthropic.claude-opus-4-1-20250805-v1:0',
          'inferenceTypesSupported' => ['INFERENCE_PROFILE']
        }
      end

      it 'adds eu. prefix for inference profile models' do
        result = provider_instance.send(:model_id_with_region,
                                        inference_profile_model['modelId'],
                                        inference_profile_model)
        expect(result).to eq('eu.anthropic.claude-3-7-sonnet-20250219-v1:0')
      end

      it 'adds eu. prefix to us. prefixed model' do
        result = provider_instance.send(:model_id_with_region,
                                        us_prefixed_model['modelId'],
                                        us_prefixed_model)
        expect(result).to eq('eu.anthropic.claude-opus-4-1-20250805-v1:0')
      end
    end

    context 'with AP region configured' do
      let(:provider_instance) do
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('ap-south-1')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)
        provider
      end

      it 'adds ap. prefix to existing us. prefixed model' do
        model_data = {
          'modelId' => 'us.anthropic.claude-opus-4-1-20250805-v1:0',
          'inferenceTypesSupported' => ['INFERENCE_PROFILE']
        }

        result = provider_instance.send(:model_id_with_region,
                                        model_data['modelId'],
                                        model_data)
        expect(result).to eq('ap.anthropic.claude-opus-4-1-20250805-v1:0')
      end
    end

    context 'with region prefix edge cases' do
      it 'handles empty region gracefully' do
        allow(RubyLLM.config).to receive(:bedrock_region).and_return('')
        provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
        provider.extend(described_class)

        model_data = {
          'modelId' => 'anthropic.claude-opus-4-1-20250805-v1:0',
          'inferenceTypesSupported' => ['INFERENCE_PROFILE']
        }

        result = provider.send(:model_id_with_region,
                               model_data['modelId'],
                               model_data)
        expect(result).to eq('us.anthropic.claude-opus-4-1-20250805-v1:0')
      end

      it 'extracts region prefix from various AWS regions' do
        regions_and_expected_prefixes = {
          'eu-west-3' => 'eu',
          'ap-south-1' => 'ap',
          'ca-central-1' => 'ca',
          'sa-east-1' => 'sa'
        }

        regions_and_expected_prefixes.each do |region, expected_prefix|
          allow(RubyLLM.config).to receive(:bedrock_region).and_return(region)
          provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
          provider.extend(described_class)

          model_data = {
            'modelId' => 'anthropic.claude-opus-4-1-20250805-v1:0',
            'inferenceTypesSupported' => ['INFERENCE_PROFILE']
          }

          result = provider.send(:model_id_with_region,
                                 model_data['modelId'],
                                 model_data)
          expect(result).to eq("#{expected_prefix}.anthropic.claude-opus-4-1-20250805-v1:0")
        end
      end
    end
  end
end
