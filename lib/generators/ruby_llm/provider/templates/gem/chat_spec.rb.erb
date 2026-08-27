# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  each_model(CHAT_MODELS) do |provider, model|
    it "#{provider}/#{model} can have a basic conversation" do
      response = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true).ask("What's 2 + 2?")

      expect(response.content).to include('4')
      expect(response.role).to eq(:assistant)
      expect(response.tokens.input.to_i).to be_positive
      expect(response.tokens.output.to_i).to be_positive
    end

    it "#{provider}/#{model} returns the raw response" do
      response = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)
                        .ask('What is the capital of France?')

      expect(response.raw.status).to eq(200)
      expect(response.raw.headers).not_to be_empty
      expect(response.raw.body).not_to be_empty
      expect(response.raw.env.request_body).not_to be_empty
    end

    it "#{provider}/#{model} can handle a multi-turn conversation" do
      chat = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)

      expect(chat.ask('Who created the programming language Ruby?').content).to match(/Matz|Matsumoto/i)
      expect(chat.ask('What year was Ruby first released?').content).to include('199')
    end
  end
end
