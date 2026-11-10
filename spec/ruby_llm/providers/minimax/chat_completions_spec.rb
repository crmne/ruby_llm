# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::ChatCompletions, :live do
  let(:schema) do
    {
      name: 'fruit_choice',
      schema: {
        type: 'object',
        properties: { fruit: { type: 'string', enum: %w[apple banana] } },
        required: ['fruit'],
        additionalProperties: false
      }
    }
  end
  let(:chat) do
    RubyLLM.chat(model: RubyLLM::Providers::MiniMax::STRUCTURED_OUTPUT_MODEL, provider: :minimax,
                 assume_model_exists: true).with_schema(schema)
  end

  it 'returns the object the schema describes, without the name MiniMax wraps it in' do
    response = chat.ask('Name a fruit.')

    expect(response.parsed).to match('fruit' => a_string_matching(/apple|banana/))
  end

  it 'refuses to stream structured output, because the wrapper arrives first' do
    expect { chat.ask('Name a fruit.') { |_chunk| nil } }.to raise_error(ArgumentError, /does not stream/)
  end

  it 'leaves other models on the Messages route' do
    other = RubyLLM.chat(model: model_for(:minimax), provider: :minimax).with_schema(schema)

    expect { other.ask('Name a fruit.') }
      .to raise_error(ArgumentError, "MiniMax's Messages API has no structured output")
  end
end
