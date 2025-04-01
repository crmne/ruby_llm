# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'streaming responses' do
    [
      ['claude-3-5-haiku-20241022', nil],
      ['gemini-2.0-flash', nil],
      ['deepseek-chat', nil],
      ['gpt-4o-mini', nil],
      %w[claude-3-5-haiku bedrock]
    ].each do |model, provider|
      provider_suffix = provider ? " with #{provider}" : ''
      it "#{model} supports streaming responses#{provider_suffix}" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM.chat(model: model, provider: provider)
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
