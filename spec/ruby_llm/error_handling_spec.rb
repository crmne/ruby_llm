# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Error do
  it 'handles invalid API keys gracefully', :live do
    RubyLLM.configure do |config|
      config.openai_api_key = 'invalid-key'
    end

    chat = RubyLLM.chat(model: model_for(:openai, :temperature))

    expect do
      chat.ask('Hello')
    end.to raise_error(RubyLLM::UnauthorizedError)
  end
end
