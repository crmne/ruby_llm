# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'streaming responses' do
    [
      'claude-3-5-haiku-20241022',
      'gemini-2.0-flash',
      'deepseek-chat',
      'gpt-4o-mini',
      'smollm:135m'
    ].each do |model|
      it "#{model} supports streaming responses" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
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
