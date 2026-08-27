# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  let(:person_schema) do
    {
      type: 'object',
      properties: {
        name: { type: 'string' },
        age: { type: 'integer' }
      },
      required: %w[name age],
      additionalProperties: false
    }
  end

  each_model(STRUCTURED_OUTPUT_MODELS) do |provider, model|
    it "#{provider}/#{model} returns structured output" do
      response = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)
                        .with_schema(person_schema)
                        .ask('Generate a person named John who is 30 years old')

      expect(response.content).to be_a(String)
      expect(response.parsed).to include('name' => 'John', 'age' => 30)
    end
  end
end
