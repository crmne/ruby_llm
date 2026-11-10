# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama::Responses, :live do
  it 'searches the web on the Responses protocol and continues the conversation' do
    chat = RubyLLM.chat(model: model_for(:ollama), provider: :ollama, protocol: :responses)
                  .with_provider_tools(:web_search)

    response = chat.ask('Search the web: what is the latest stable Ruby version? Answer in one short sentence.')

    expect(response.server_tool_calls.map(&:type)).to include('web_search_call')
    expect(response.content).to match(/\d+\.\d+/)

    follow_up = chat.ask('Reply with only the major version number from your answer.')

    expect(follow_up.content).to match(/\d/)
  end
end
