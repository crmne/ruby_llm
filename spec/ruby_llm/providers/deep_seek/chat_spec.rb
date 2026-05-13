# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::DeepSeek::Chat do
  describe '.format_thinking' do
    context 'with an assistant message' do
      it 'emits reasoning_content (and reasoning) when thinking text is present' do
        message = RubyLLM::Message.new(
          role: :assistant,
          content: 'Hi',
          thinking: RubyLLM::Thinking.build(text: 'pondering', signature: 'sig')
        )

        payload = described_class.format_thinking(message)

        expect(payload[:reasoning_content]).to eq('pondering')
        expect(payload[:reasoning]).to eq('pondering')
        expect(payload[:reasoning_signature]).to eq('sig')
      end

      it 'still emits reasoning_content when no thinking was captured' do
        message = RubyLLM::Message.new(role: :assistant, content: 'short answer')

        payload = described_class.format_thinking(message)

        expect(payload).to have_key(:reasoning_content)
        expect(payload[:reasoning_content]).to eq('')
        expect(payload).not_to have_key(:reasoning)
      end
    end

    it 'returns an empty hash for non-assistant messages' do
      message = RubyLLM::Message.new(role: :user, content: 'hello')

      expect(described_class.format_thinking(message)).to eq({})
    end
  end
end
