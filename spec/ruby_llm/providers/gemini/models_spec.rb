# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Models do
  describe '.parse_list_models_response' do
    let(:response_class) { Struct.new(:body) }

    let(:response) do
      instance_double(
        response_class,
        body: {
          'models' => [
            {
              'name' => 'models/gemini-2.0-flash-001',
              'displayName' => 'Gemini 2.0 Flash',
              'version' => '001',
              'description' => 'Fast Gemini model',
              'supportedGenerationMethods' => ['generateContent']
            }
          ]
        }
      )
    end

    it 'restores only critical fallback metadata for sparse models' do
      model = described_class.parse_list_models_response(
        response,
        'gemini',
        RubyLLM::Providers::Gemini::Capabilities
      ).first

      expect(model.id).to eq('gemini-2.0-flash-001')
      expect(model.name).to eq('Gemini 2.0 Flash')
      expect(model.provider).to eq('gemini')
      expect(model.family).to be_nil
      expect(model.context_window).to eq(1_048_576)
      expect(model.max_output_tokens).to eq(8192)
      expect(model.capabilities).to contain_exactly('function_calling', 'structured_output', 'vision')
      expect(model.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.1,
            output_per_million: 0.4
          }
        }
      )
      expect(model.metadata).to eq(
        version: '001',
        description: 'Fast Gemini model',
        supported_generation_methods: ['generateContent']
      )
    end
  end
end
