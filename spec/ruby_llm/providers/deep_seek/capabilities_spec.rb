# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::DeepSeek::Capabilities do
  describe '.critical_capabilities_for' do
    it 'restores critical metadata for current DeepSeek models' do
      expect(described_class.critical_capabilities_for('deepseek-chat')).to eq(['function_calling'])
      expect(described_class.critical_capabilities_for('deepseek-reasoner')).to eq(
        %w[function_calling reasoning]
      )
      expect(described_class.critical_capabilities_for('deepseek-v4-flash')).to eq(
        %w[function_calling structured_output reasoning]
      )
    end
  end

  describe '.pricing_for' do
    it 'uses DeepSeek pricing fallbacks for the live models endpoint' do
      expect(described_class.pricing_for('deepseek-chat')).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.14,
            output_per_million: 0.28,
            cache_read_input_per_million: 0.0028
          }
        }
      )
      expect(described_class.pricing_for('deepseek-v4-pro')[:text_tokens][:standard]).to eq(
        input_per_million: 0.435,
        output_per_million: 0.87,
        cache_read_input_per_million: 0.003625
      )
    end
  end

  describe 'OpenAI parser integration' do
    it 'parses DeepSeek models with provider-specific fallbacks' do
      response = Struct.new(:body).new(
        {
          'data' => [
            {
              'id' => 'deepseek-v4-pro',
              'object' => 'model',
              'created' => 1_777_068_000,
              'owned_by' => 'deepseek'
            }
          ]
        }
      )

      model = RubyLLM::Providers::OpenAI::Models.parse_list_models_response(
        response,
        'deepseek',
        described_class
      ).first

      expect(model.id).to eq('deepseek-v4-pro')
      expect(model.provider).to eq('deepseek')
      expect(model.context_window).to eq(1_000_000)
      expect(model.max_output_tokens).to eq(384_000)
      expect(model.capabilities).to eq(%w[function_calling structured_output reasoning])
      expect(model.pricing.to_h).to eq(described_class.pricing_for('deepseek-v4-pro'))
    end
  end
end
