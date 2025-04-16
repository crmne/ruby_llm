# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  chat_models = %w[claude-3-5-haiku-20241022
                   anthropic.claude-3-5-haiku-20241022-v1:0
                   gemini-2.0-flash
                   deepseek-chat
                   gpt-4.1-nano].freeze

  describe 'streaming responses' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      it "#{provider}/#{model} supports streaming responses" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model)
        chunks = []

        chat.ask('Count from 1 to 3') do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(chunks.first).to be_a(RubyLLM::Chunk)
      end
    end
  end
end
