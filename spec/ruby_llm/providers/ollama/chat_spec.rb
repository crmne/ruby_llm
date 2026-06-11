# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama::Chat do
  describe '.format_messages' do
    it 'includes empty content when replaying a thinking-only assistant message' do
      thinking = RubyLLM::Thinking.new(text: 'I should reason first')
      message = RubyLLM::Message.new(role: :assistant, content: nil, thinking: thinking)
      provider = RubyLLM::Providers::Ollama::ChatCompletions.allocate

      formatted = provider.send(:format_messages, [message])

      expect(formatted.first[:content]).to eq('')
      expect(formatted.first[:reasoning_content]).to eq('I should reason first')
    end
  end
end
