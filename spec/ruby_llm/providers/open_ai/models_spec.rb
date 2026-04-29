# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Models do
  describe '.parse_list_models_response' do
    let(:response_class) { Struct.new(:body) }
    let(:capabilities) { RubyLLM::Providers::OpenAI::Capabilities }

    let(:response) do
      instance_double(
        response_class,
        body: {
          'data' => [
            {
              'id' => 'gpt-3.5-turbo-0125',
              'created' => 1_741_110_400,
              'object' => 'model',
              'owned_by' => 'system'
            },
            {
              'id' => 'omni-moderation-latest',
              'created' => 1_741_110_401,
              'object' => 'model',
              'owned_by' => 'system'
            }
          ]
        }
      )
    end

    def parse_models(response_body, capabilities)
      described_class.parse_list_models_response(
        instance_double(response_class, body: response_body),
        'openai',
        capabilities
      )
    end

    def parsed_model(id, capabilities)
      parse_models(response.body, capabilities).find { |entry| entry.id == id }
    end

    it 'restores only critical fallback metadata for sparse models' do
      model = parsed_model('gpt-3.5-turbo-0125', capabilities)

      expect(model.name).to eq('gpt-3.5-turbo-0125')
      expect(model.family).to be_nil
      expect(model.context_window).to eq(16_385)
      expect(model.max_output_tokens).to eq(4096)
      expect(model.capabilities).to eq([])
      expect(model.pricing.to_h).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.5,
            output_per_million: 1.5
          }
        }
      )
      expect(model.metadata).to eq(object: 'model', owned_by: 'system')
    end

    it 'restores critical capabilities for reasoning models' do
      reasoning_model = parse_models(
        {
          'data' => [
            {
              'id' => 'gpt-5.4-nano',
              'created' => 1_741_110_402,
              'object' => 'model',
              'owned_by' => 'system'
            }
          ]
        },
        capabilities
      ).first

      expect(reasoning_model.capabilities).to contain_exactly(
        'function_calling',
        'structured_output',
        'vision',
        'reasoning'
      )
    end

    it 'restores only critical capabilities to moderation models' do
      model = parsed_model('omni-moderation-latest', capabilities)

      expect(model.capabilities).to eq(['vision'])
      expect(model.pricing.to_h).to eq({})
    end
  end
end
