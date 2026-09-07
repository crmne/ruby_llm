# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity::Chat do
  it 'returns Sonar JSON Schema output through with_schema', :live do
    schema = {
      type: 'object',
      properties: { name: { type: 'string' }, year: { type: 'integer' } },
      required: %w[name year],
      additionalProperties: false
    }

    message = RubyLLM.chat(model: model_for(:perplexity), provider: :perplexity)
                     .with_schema(schema)
                     .ask('Extract these two facts: Ruby was released in 1995. Return its name and release year.')

    expect(message.content).to be_a(String)
    expect(message.parsed).to eq('name' => 'Ruby', 'year' => 1995)
    expect(message.tokens.input).to be_positive
  end
end
