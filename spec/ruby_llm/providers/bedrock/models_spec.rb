# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Models do
  let(:slug) { 'bedrock' }

  def build_provider(region)
    provider = RubyLLM::Providers::Bedrock.allocate
    provider.instance_variable_set(:@config, instance_double(RubyLLM::Configuration, bedrock_region: region))
    provider.extend(described_class)
    provider
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
        provider = build_provider('us-east-1')

        model_info = provider.send(:create_model_info, model_data, slug, nil)
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
        provider = build_provider('us-east-1')

        model_info = provider.send(:create_model_info, model_data, slug, nil)
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
        provider = build_provider('us-east-1')

        model_info = provider.send(:create_model_info, model_data, slug, nil)
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
        provider = build_provider('us-east-1')

        model_info = provider.send(:create_model_info, model_data, slug, nil)
        expect(model_info.id).to eq('anthropic.claude-3-5-sonnet-20240620-v1:0')
      end
    end
  end

  # New specs for region-aware inference profile handling
  describe '#model_id_with_region with region awareness' do
    let(:provider_instance) { build_provider('eu-west-3') }

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
      let(:provider_instance) { build_provider('ap-south-1') }

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
        provider = build_provider('')

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
          provider = build_provider(region)

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
