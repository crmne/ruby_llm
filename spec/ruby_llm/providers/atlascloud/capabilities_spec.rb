# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::AtlasCloud::Capabilities do
  describe 'OpenAI parser integration' do
    it 'parses Atlas Cloud models with live-verified limits' do
      response = Struct.new(:body).new(
        {
          'data' => [
            {
              'id' => 'deepseek-ai/deepseek-v4-pro',
              'object' => 'model',
              'created' => 1_783_036_800,
              'owned_by' => 'atlascloud'
            }
          ]
        }
      )

      model = RubyLLM::Protocols::ChatCompletions::Models.parse_list_models_response(
        response,
        'atlascloud',
        described_class
      ).first

      expect(model.id).to eq('deepseek-ai/deepseek-v4-pro')
      expect(model.provider).to eq('atlascloud')
      expect(model.context_window).to eq(1_048_576)
      expect(model.max_output_tokens).to eq(393_216)
      expect(model.capabilities).to eq([])
      expect(model.pricing.to_h).to eq({})
    end
  end
end
