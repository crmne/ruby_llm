# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Models do
  describe '.parse_list_models_response' do
    let(:response_class) { Struct.new(:body) }

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

    def parse_models(response_body)
      described_class.parse_list_models_response(
        instance_double(response_class, body: response_body),
        'openai'
      )
    end

    def parsed_model(id)
      parse_models(response.body).find { |entry| entry.id == id }
    end

    it 'keeps only metadata the provider reports' do
      model = parsed_model('gpt-3.5-turbo-0125')

      expect(model.name).to eq('gpt-3.5-turbo-0125')
      expect(model.family).to be_nil
      expect(model.context_window).to be_nil
      expect(model.max_output_tokens).to be_nil
      expect(model.capabilities).to eq([])
      expect(model.pricing.to_h).to eq({})
      expect(model.metadata).to eq(object: 'model', owned_by: 'system')
    end

    it 'does not guess metadata from a model id' do
      model = parse_models(
        {
          'data' => [
            {
              'id' => 'gpt-5.4-nano-2026-03-17',
              'created' => 1_741_110_402,
              'object' => 'model',
              'owned_by' => 'system'
            }
          ]
        }
      ).first

      expect(model.context_window).to be_nil
      expect(model.max_output_tokens).to be_nil
      expect(model.capabilities).to be_empty
      expect(model.pricing.to_h).to be_empty
    end

    it 'keeps the retirement date the provider reports' do
      model = parse_models(
        {
          'data' => [
            {
              'id' => 'gpt-5-codex',
              'created' => 1_741_110_403,
              'object' => 'model',
              'owned_by' => 'system',
              'shutdown_date' => '2026-07-23'
            }
          ]
        }
      ).first

      expect(model.metadata).to eq(object: 'model', owned_by: 'system', shutdown_date: '2026-07-23')
    end

    it 'omits the retirement date for providers that do not report one' do
      expect(parsed_model('gpt-3.5-turbo-0125').metadata).not_to have_key(:shutdown_date)
    end
  end
end
