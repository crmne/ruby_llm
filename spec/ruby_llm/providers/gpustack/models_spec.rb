# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Models do
  subject(:protocol) { RubyLLM::Providers::GPUStack::ChatCompletions.new(provider) }

  let(:config) { RubyLLM::Configuration.new }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:provider) do
    instance_double(RubyLLM::Providers::GPUStack, config: config, connection: connection, slug: 'gpustack')
  end

  def response_for(*data)
    instance_double(Faraday::Response, body: { 'object' => 'list', 'data' => data })
  end

  def stub_categories(models_by_category)
    described_class::CATEGORIES.each do |category|
      allow(connection).to receive(:get)
        .with("models?with_meta=true&categories=#{category}")
        .and_return(response_for(*Array(models_by_category[category])))
    end
  end

  describe '#models_url' do
    it 'asks the catalog for model meta' do
      expect(protocol.models_url).to eq('models?with_meta=true')
    end
  end

  describe '#list_models' do
    it 'queries each category and maps the OpenAI list format onto Models' do
      stub_categories(
        'llm' => [{
          'id' => 'qwen3',
          'object' => 'model',
          'created' => 1_735_770_000,
          'owned_by' => 'gpustack',
          'meta' => { 'n_ctx' => 32_768, 'support_tool_calls' => true, 'support_reasoning' => true }
        }],
        'embedding' => [{ 'id' => 'bge-m3', 'object' => 'model', 'owned_by' => 'gpustack' }]
      )

      models = protocol.list_models

      expect(models.map(&:id)).to contain_exactly('qwen3', 'bge-m3')

      qwen = models.find { |model| model.id == 'qwen3' }
      expect(qwen.provider).to eq('gpustack')
      expect(qwen.family).to eq('gpustack')
      expect(qwen.created_at).to eq(Time.at(1_735_770_000))
      expect(qwen.context_window).to eq(32_768)
      expect(qwen.capabilities).to contain_exactly(
        'streaming', 'structured_output', 'json_mode', 'function_calling', 'reasoning'
      )
      expect(qwen.modalities.input).to eq(['text'])
      expect(qwen.modalities.output).to eq(['text'])
      expect(qwen.metadata).to include(owned_by: 'gpustack', categories: ['llm'])
    end

    it 'keeps owner-prefixed ids and reads vLLM-style meta' do
      stub_categories(
        'llm' => [{
          'id' => 'alice/qwen3-vl',
          'object' => 'model',
          'owned_by' => 'alice',
          'meta' => { 'max_model_len' => 131_072, 'support_vision' => true, 'support_audio' => true }
        }]
      )

      model = protocol.list_models.first

      expect(model.id).to eq('alice/qwen3-vl')
      expect(model.context_window).to eq(131_072)
      expect(model.capabilities).to include('vision')
      expect(model.modalities.input).to eq(%w[text image audio])
    end

    it 'merges models that appear under several categories' do
      stub_categories(
        'speech_to_text' => [{ 'id' => 'voxbox', 'object' => 'model', 'owned_by' => 'gpustack' }],
        'text_to_speech' => [{ 'id' => 'voxbox', 'object' => 'model', 'owned_by' => 'gpustack' }]
      )

      models = protocol.list_models

      expect(models.length).to eq(1)
      expect(models.first.metadata[:categories]).to eq(%w[speech_to_text text_to_speech])
      expect(models.first.modalities.input).to eq(%w[text audio])
      expect(models.first.modalities.output).to eq(%w[text audio])
    end

    it 'maps image and embedding categories onto their output modality' do
      stub_categories(
        'embedding' => [{ 'id' => 'bge-m3', 'object' => 'model', 'owned_by' => 'gpustack' }],
        'image' => [{ 'id' => 'flux.1', 'object' => 'model', 'owned_by' => 'gpustack' }]
      )

      models = protocol.list_models
      embedding = models.find { |model| model.id == 'bge-m3' }
      image = models.find { |model| model.id == 'flux.1' }

      expect(embedding.capabilities).to be_empty
      expect(embedding.modalities.output).to eq(['embeddings'])
      expect(image.modalities.output).to eq(['image'])
    end

    it 'returns an empty list when no category has models' do
      stub_categories({})

      expect(protocol.list_models).to eq([])
    end
  end

  describe '#parse_list_models_response' do
    it 'parses a plain OpenAI list without meta or categories' do
      response = response_for('id' => 'qwen3', 'object' => 'model', 'owned_by' => 'gpustack')

      model = protocol.parse_list_models_response(response, 'gpustack', nil).first

      expect(model).to be_a(RubyLLM::Model)
      expect(model.id).to eq('qwen3')
      expect(model.created_at).to be_nil
      expect(model.context_window).to be_nil
      expect(model.capabilities).to be_empty
      expect(model.pricing.to_h).to eq({})
    end

    it 'returns an empty list when the payload has no data' do
      response = instance_double(Faraday::Response, body: {})

      expect(protocol.parse_list_models_response(response, 'gpustack', nil)).to eq([])
    end
  end
end
