# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Models do
  # The module marks its methods private; the protocol only ever calls them on itself.
  subject(:parser) do
    Class.new do
      include RubyLLM::Providers::GPUStack::Models

      public :models_url, :parse_list_models_response
    end.new
  end

  def response_for(*items)
    Struct.new(:body).new({ 'items' => items })
  end

  describe '#models_url' do
    it 'points at the GPUStack catalog endpoint' do
      expect(parser.models_url).to eq('models')
    end
  end

  describe '#parse_list_models_response' do
    it 'returns an empty list when the payload has no items' do
      response = Struct.new(:body).new({})

      expect(parser.parse_list_models_response(response, 'gpustack', nil)).to eq([])
    end

    it 'maps the GPUStack payload onto a Model' do
      response = response_for(
        'name' => 'qwen3',
        'created_at' => '2025-01-02T03:04:05Z',
        'description' => 'Qwen 3',
        'source' => 'huggingface',
        'huggingface_repo_id' => 'Qwen/Qwen3',
        'ollama_library_model_name' => 'qwen3',
        'backend' => 'vllm',
        'categories' => ['llm'],
        'meta' => { 'n_ctx' => 32_768 }
      )

      model = parser.parse_list_models_response(response, 'gpustack', nil).first

      expect(model).to be_a(RubyLLM::Model)
      expect(model.id).to eq('qwen3')
      expect(model.name).to eq('qwen3')
      expect(model.provider).to eq('gpustack')
      expect(model.family).to eq('gpustack')
      expect(model.created_at).to eq(Time.parse('2025-01-02T03:04:05Z'))
      expect(model.context_window).to eq(32_768)
      expect(model.max_output_tokens).to eq(32_768)
      expect(model.pricing.to_h).to eq({})
      expect(model.metadata).to include(
        description: 'Qwen 3',
        source: 'huggingface',
        huggingface_repo_id: 'Qwen/Qwen3',
        ollama_library_model_name: 'qwen3',
        backend: 'vllm'
      )
    end

    it 'leaves created_at nil when GPUStack omits it' do
      model = parser.parse_list_models_response(
        response_for('name' => 'qwen3', 'categories' => ['llm']), 'gpustack', nil
      ).first

      expect(model.created_at).to be_nil
    end

    it 'gives LLM models the baseline chat capabilities' do
      model = parser.parse_list_models_response(
        response_for('name' => 'qwen3', 'categories' => ['llm']), 'gpustack', nil
      ).first

      expect(model.capabilities).to contain_exactly('streaming', 'structured_output', 'json_mode')
      expect(model.modalities.input).to eq(['text'])
      expect(model.modalities.output).to eq(['text'])
    end

    it 'derives the optional capabilities from the model meta' do
      model = parser.parse_list_models_response(
        response_for(
          'name' => 'qwen3-vl',
          'categories' => ['llm'],
          'meta' => {
            'support_tool_calls' => true,
            'support_vision' => true,
            'support_reasoning' => true,
            'support_audio' => true
          }
        ), 'gpustack', nil
      ).first

      expect(model.capabilities).to include('function_calling', 'vision', 'reasoning')
      expect(model.modalities.input).to eq(%w[text image audio])
    end

    it 'maps embedding models to an embeddings output' do
      model = parser.parse_list_models_response(
        response_for('name' => 'bge-m3', 'categories' => ['embedding']), 'gpustack', nil
      ).first

      expect(model.capabilities).to be_empty
      expect(model.modalities.input).to eq(['text'])
      expect(model.modalities.output).to eq(['embeddings'])
    end

    it 'leaves modalities empty for uncategorized models' do
      model = parser.parse_list_models_response(
        response_for('name' => 'mystery'), 'gpustack', nil
      ).first

      expect(model.capabilities).to be_empty
      expect(model.modalities.input).to be_empty
      expect(model.modalities.output).to be_empty
    end
  end
end
