# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'can ask using the first configured chat model' do
    model_info = CHAT_MODELS.first

    agent_class = Class.new(RubyLLM::Agent) do
      model model_info[:model], provider: model_info[:provider]
      instructions 'Answer questions clearly.'
    end

    stub_const('SpecChatAgent', agent_class)

    response = SpecChatAgent.new.ask("What's 2 + 2?")
    expect(response.content).to include('4')
    expect(response.role).to eq(:assistant)
  end
end
