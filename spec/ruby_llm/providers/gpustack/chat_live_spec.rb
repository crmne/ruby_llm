# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Chat, :live do
  let(:context) do
    RubyLLM.context { |config| config.gpustack_api_base = 'http://localhost:11444/model/proxy/2/v1' }
  end
  let(:chat) do
    context.chat(model: 'smollm2-135m', provider: :gpustack, assume_model_exists: true).with_max_output_tokens(8)
  end

  it 'counts the tokens the next request uses' do
    chat.with_instructions('Be terse.')

    count = chat.count_tokens('Name one colour.')
    response = chat.ask('Name one colour.')

    expect(count).to eq(response.tokens.input)
    expect(count).to be_positive
  end

  it 'truncates a long prompt to the compaction threshold and still answers' do
    response = chat.with_compaction(at: 40).ask("#{'filler ' * 3000}Name one colour.")

    expect(response.tokens.input).to be_between(1, 40)
    expect(response.content).not_to be_empty
  end

  it 'fits an overflowing prompt into the model window with no threshold' do
    response = chat.with_compaction.ask("#{'filler ' * 3000}Name one colour.")

    expect(response.tokens.input).to be_between(1, 2040)
    expect(response.content).not_to be_empty
  end
end
