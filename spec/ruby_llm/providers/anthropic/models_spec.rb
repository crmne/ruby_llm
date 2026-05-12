# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Models do
  describe '.parse_list_models_response' do
    let(:response_class) { Struct.new(:body) }

    let(:response) do
      instance_double(
        response_class,
        body: {
          'data' => [
            {
              'id' => 'claude-sonnet-4-5',
              'display_name' => 'Claude Sonnet 4.5',
              'created_at' => '2026-01-02T03:04:05Z'
            }
          ]
        }
      )
    end

    it 'returns minimal provider metadata for models covered by models.dev' do
      model = described_class.parse_list_models_response(
        response,
        'anthropic',
        RubyLLM::Providers::Anthropic::Capabilities
      ).first

      expect(model.id).to eq('claude-sonnet-4-5')
      expect(model.name).to eq('Claude Sonnet 4.5')
      expect(model.provider).to eq('anthropic')
      expect(model.created_at).to eq(Time.parse('2026-01-02T03:04:05Z'))
      expect(model.family).to be_nil
      expect(model.context_window).to be_nil
      expect(model.max_output_tokens).to be_nil
      expect(model.capabilities).to eq([])
      expect(model.pricing.to_h).to eq({})
    end
  end
end
