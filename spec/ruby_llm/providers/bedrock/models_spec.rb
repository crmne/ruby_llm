# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Models do
  subject(:provider) { RubyLLM::Providers::Bedrock.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |c|
      c.bedrock_region = 'us-east-1'
      c.bedrock_api_key = 'key'
      c.bedrock_secret_key = 'secret'
    end
  end

  describe '#models_api_base' do
    it 'derives the control-plane host from the region' do
      expect(provider.send(:models_api_base)).to eq('https://bedrock.us-east-1.amazonaws.com')
    end

    it 'prefers an explicitly configured base' do
      config.bedrock_api_base = 'https://bedrock.example.test'

      expect(provider.send(:models_api_base)).to eq('https://bedrock.example.test')
    end
  end

  describe '#models_url' do
    it 'lists foundation models' do
      expect(provider.send(:models_url)).to eq('/foundation-models')
    end
  end

  describe '#parse_list_models_response' do
    let(:model_data) do
      {
        'modelId' => 'anthropic.claude-haiku-4-5-20251001-v1:0',
        'modelName' => 'Claude Haiku 4.5',
        'modelArn' => 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5',
        'providerName' => 'Anthropic',
        'inputModalities' => %w[TEXT IMAGE],
        'outputModalities' => ['TEXT'],
        'inferenceTypesSupported' => ['ON_DEMAND'],
        'responseStreamingSupported' => true,
        'description' => { 'maxContextWindow' => '200k' },
        'converse' => { 'maxTokensDefault' => 8192, 'reasoningSupported' => { 'embedded' => true } }
      }
    end

    it 'returns an empty list when Bedrock sends no summaries' do
      response = Struct.new(:body).new({})

      expect(provider.send(:parse_list_models_response, response, 'bedrock', nil)).to eq([])
    end

    it 'maps a model summary onto a Model' do
      response = Struct.new(:body).new({ 'modelSummaries' => [model_data] })

      model = provider.send(:parse_list_models_response, response, 'bedrock', nil).first

      expect(model.id).to eq('anthropic.claude-haiku-4-5-20251001-v1:0')
      expect(model.name).to eq('Claude Haiku 4.5')
      expect(model.provider).to eq('bedrock')
      expect(model.family).to eq('anthropic')
      expect(model.created_at).to be_nil
      expect(model.context_window).to eq(200_000)
      expect(model.max_output_tokens).to eq(8192)
      expect(model.modalities.input).to eq(%w[text image])
      expect(model.modalities.output).to eq(['text'])
      expect(model.capabilities).to contain_exactly(
        'streaming', 'function_calling', 'reasoning', 'structured_output'
      )
      expect(model.metadata).to include(provider_name: 'Anthropic', inference_types: ['ON_DEMAND'])
    end

    it 'prefers modelFamily over the provider name' do
      model = provider.send(:create_model_info, model_data.merge('modelFamily' => 'claude'), 'bedrock')

      expect(model.family).to eq('claude')
    end

    it 'leaves the family nil when neither is present' do
      model = provider.send(
        :create_model_info, model_data.except('modelFamily', 'providerName'), 'bedrock'
      )

      expect(model.family).to be_nil
    end

    it 'falls back to the maximum output tokens Bedrock reports' do
      model = provider.send(
        :create_model_info, model_data.merge('converse' => { 'maxTokensMaximum' => 4096 }), 'bedrock'
      )

      expect(model.max_output_tokens).to eq(4096)
    end

    it 'region-prefixes ids that are only served through an inference profile' do
      model = provider.send(
        :create_model_info, model_data.merge('inferenceTypesSupported' => ['INFERENCE_PROFILE']), 'bedrock'
      )

      expect(model.id).to eq('us.anthropic.claude-haiku-4-5-20251001-v1:0')
    end
  end

  describe '#normalize_modalities' do
    it 'downcases and renames the Bedrock modality vocabulary' do
      expect(provider.send(:normalize_modalities, %w[TEXT EMBEDDING SPEECH IMAGE])).to eq(
        %w[text embeddings audio image]
      )
    end

    it 'treats a missing list as empty' do
      expect(provider.send(:normalize_modalities, nil)).to eq([])
    end
  end

  describe '#parse_capabilities' do
    it 'treats a missing converse block as an empty one' do
      expect(provider.send(:parse_capabilities, { 'modelId' => 'amazon.titan-text-v1' })).to eq(['function_calling'])
    end

    it 'reports only what the summary claims' do
      capabilities = provider.send(
        :parse_capabilities,
        { 'modelId' => 'amazon.nova-2-lite-v1:0', 'responseStreamingSupported' => false, 'converse' => {} }
      )

      expect(capabilities).to eq(['function_calling'])
    end
  end

  describe '#parse_context_window' do
    {
      { 'maxContextWindow' => '200k' } => 200_000,
      { 'maxContextWindow' => '128K' } => 128_000,
      { 'maxContextWindow' => '32000' } => 32_000,
      { 'maxContextWindow' => 'unknown' } => nil,
      { 'maxContextWindow' => 8192 } => nil,
      {} => nil
    }.each do |description, expected|
      it "reads #{description.inspect} as #{expected.inspect}" do
        expect(provider.send(:parse_context_window, { 'description' => description })).to eq(expected)
      end
    end

    it 'ignores a missing description' do
      expect(provider.send(:parse_context_window, {})).to be_nil
    end
  end

  describe '#region_prefix and #with_region_prefix' do
    it 'takes the leading segment of the region' do
      expect(provider.send(:region_prefix, 'eu-west-1')).to eq('eu')
    end

    it 'defaults to us when the region is blank' do
      expect(provider.send(:region_prefix, '')).to eq('us')
      expect(provider.send(:region_prefix, nil)).to eq('us')
    end

    it 'rewrites an existing prefix rather than stacking one' do
      expect(provider.send(:with_region_prefix, 'us.anthropic.claude', 'eu-west-1')).to eq('eu.anthropic.claude')
      expect(provider.send(:with_region_prefix, 'anthropic.claude', 'eu-west-1')).to eq('eu.anthropic.claude')
    end
  end

  describe '#normalize_inference_profile_id' do
    it 'leaves ids that are not inference-profile only' do
      expect(provider.send(:normalize_inference_profile_id, 'model', [], 'us-east-1')).to eq('model')
      expect(
        provider.send(:normalize_inference_profile_id, 'model', %w[INFERENCE_PROFILE ON_DEMAND], 'us-east-1')
      ).to eq('model')
    end

    it 'prefixes ids that only exist as an inference profile' do
      expect(
        provider.send(:normalize_inference_profile_id, 'model', ['INFERENCE_PROFILE'], 'eu-west-1')
      ).to eq('eu.model')
    end
  end

  describe '.resolve_registry_id' do
    let(:models) do
      RubyLLM::Models.new(
        [
          RubyLLM::Model.new(
            id: 'us.meta.llama4-maverick-v1:0',
            provider: 'bedrock',
            metadata: { inference_types: ['INFERENCE_PROFILE'] }
          )
        ]
      )
    end

    it 'returns the id unchanged when no region is configured' do
      expect(described_class.resolve_registry_id('meta.llama4-maverick-v1:0', models, config_for(region: ''))).to eq(
        'meta.llama4-maverick-v1:0'
      )
    end

    it 'returns the id unchanged when it already carries the region prefix' do
      expect(
        described_class.resolve_registry_id('us.meta.llama4-maverick-v1:0', models, config_for)
      ).to eq('us.meta.llama4-maverick-v1:0')
    end

    it 'returns the id unchanged when the registry has no prefixed entry' do
      expect(described_class.resolve_registry_id('meta.unknown-v1:0', models, config_for)).to eq('meta.unknown-v1:0')
    end

    it 'resolves to the prefixed id when the registry entry is inference-profile only' do
      expect(described_class.resolve_registry_id('meta.llama4-maverick-v1:0', models, config_for)).to eq(
        'us.meta.llama4-maverick-v1:0'
      )
    end

    it 'reads string-keyed inference types too' do
      string_keyed = RubyLLM::Models.new(
        [
          RubyLLM::Model.new(
            id: 'us.meta.llama4-maverick-v1:0',
            provider: 'bedrock',
            metadata: { 'inference_types' => ['INFERENCE_PROFILE'] }
          )
        ]
      )

      expect(described_class.resolve_registry_id('meta.llama4-maverick-v1:0', string_keyed, config_for)).to eq(
        'us.meta.llama4-maverick-v1:0'
      )
    end

    def config_for(region: 'us-east-1')
      RubyLLM::Configuration.new.tap { |c| c.bedrock_region = region }
    end
  end

  describe '.supports_structured_output?' do
    {
      'anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'anthropic.claude-sonnet-4-5-20250929-v1:0' => true,
      'anthropic.claude-opus-4-5-20250514-v1:0' => true,
      'us.anthropic.claude-opus-4-6-v1' => true,
      'eu.anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'global.anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'anthropic.claude-opus-4-20250514-v1:0' => false,
      'anthropic.claude-3-5-sonnet-20241022-v2:0' => false,
      'amazon.nova-2-lite-v1:0' => false,
      nil => false
    }.each do |model_id, expected|
      it "returns #{expected} for #{model_id.inspect}" do
        expect(described_class.supports_structured_output?(model_id)).to eq(expected)
      end
    end
  end
end
