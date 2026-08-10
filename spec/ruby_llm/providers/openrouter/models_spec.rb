# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Models do
  # The module marks its methods private; the protocol only ever calls them on itself.
  subject(:parser) do
    Class.new do
      include RubyLLM::Providers::OpenRouter::Models

      public :models_url, :parse_list_models_response, :supported_parameters_to_capabilities
    end.new
  end

  def response_for(*models)
    Struct.new(:body).new({ 'data' => models })
  end

  describe '#models_url' do
    it 'points at the OpenRouter catalog endpoint' do
      expect(parser.models_url).to eq('models')
    end
  end

  describe '#parse_list_models_response' do
    it 'returns an empty list when the payload has no data' do
      expect(parser.parse_list_models_response(Struct.new(:body).new({}), 'openrouter', nil)).to eq([])
    end

    it 'maps the OpenRouter payload onto a Model' do
      response = response_for(
        'id' => 'anthropic/claude-haiku-4-5',
        'name' => 'Anthropic: Claude Haiku 4.5',
        'description' => 'Fast Claude',
        'created' => 1_700_000_000,
        'context_length' => 200_000,
        'architecture' => { 'input_modalities' => %w[text image], 'output_modalities' => ['text'] },
        'top_provider' => { 'max_completion_tokens' => 8192 },
        'per_request_limits' => { 'prompt_tokens' => '100' },
        'supported_parameters' => %w[tools response_format],
        'pricing' => { 'prompt' => '0.000001', 'completion' => '0.000005', 'input_cache_read' => '0.0000001' }
      )

      model = parser.parse_list_models_response(response, 'openrouter', nil).first

      expect(model.id).to eq('anthropic/claude-haiku-4-5')
      expect(model.name).to eq('Anthropic: Claude Haiku 4.5')
      expect(model.provider).to eq('openrouter')
      expect(model.family).to eq('anthropic')
      expect(model.created_at).to eq(Time.at(1_700_000_000))
      expect(model.context_window).to eq(200_000)
      expect(model.max_output_tokens).to eq(8192)
      expect(model.modalities.input).to eq(%w[text image])
      expect(model.modalities.output).to eq(['text'])
      expect(model.metadata).to include(
        description: 'Fast Claude',
        per_request_limits: { 'prompt_tokens' => '100' },
        supported_parameters: %w[tools response_format]
      )
    end

    it 'converts per-token prices to per-million and drops the zeroed ones' do
      response = response_for(
        'id' => 'vendor/model',
        'pricing' => {
          'prompt' => '0.000001',
          'completion' => '0.000005',
          'input_cache_read' => '0',
          'internal_reasoning' => '0.00001'
        }
      )

      model = parser.parse_list_models_response(response, 'openrouter', nil).first

      expect(model.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 1.0,
            output_per_million: 5.0,
            reasoning_output_per_million: 10.0
          }
        }
      )
    end

    it 'leaves created_at nil when OpenRouter omits the timestamp' do
      model = parser.parse_list_models_response(response_for('id' => 'vendor/model'), 'openrouter', nil).first

      expect(model.created_at).to be_nil
      expect(model.capabilities).to be_empty
    end
  end

  describe '#supported_parameters_to_capabilities' do
    it 'returns nothing when the model lists no parameters' do
      expect(parser.supported_parameters_to_capabilities(nil)).to eq([])
    end

    it 'always claims streaming' do
      expect(parser.supported_parameters_to_capabilities([])).to eq(['streaming'])
    end

    it 'maps tools and tool_choice to function calling' do
      expect(parser.supported_parameters_to_capabilities(['tools'])).to include('function_calling')
      expect(parser.supported_parameters_to_capabilities(['tool_choice'])).to include('function_calling')
    end

    it 'maps the remaining parameters onto capabilities' do
      capabilities = parser.supported_parameters_to_capabilities(
        %w[response_format batch logit_bias top_k]
      )

      expect(capabilities).to contain_exactly(
        'streaming', 'structured_output', 'batch', 'predicted_outputs'
      )
    end

    it 'requires both logit_bias and top_k for predicted outputs' do
      expect(parser.supported_parameters_to_capabilities(['logit_bias'])).not_to include('predicted_outputs')
    end
  end
end
