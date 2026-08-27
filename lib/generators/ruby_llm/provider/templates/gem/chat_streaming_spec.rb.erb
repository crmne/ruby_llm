# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  each_model(CHAT_MODELS) do |provider, model|
    it "#{provider}/#{model} supports streaming responses" do
      chunks = []
      chat = RubyLLM.chat(model: model, provider: provider, assume_model_exists: true)

      response = chat.ask('Count from 1 to 3') { |chunk| chunks << chunk }

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::Chunk)
      expect(response.raw.status).to eq(200)
      expect(response.raw.headers).not_to be_empty
      expect(response.raw.env.request_body).not_to be_empty
    end
  end
end
