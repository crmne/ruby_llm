# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Chat do
  let(:provider) { RubyLLM::Providers::MiniMax::ChatCompletions.allocate }

  describe '#format_thinking' do
    it 'exposes assistant reasoning as reasoning_content' do
      thinking = RubyLLM::Thinking.new(text: 'Let me reason about this')
      message = RubyLLM::Message.new(role: :assistant, content: 'Answer', thinking: thinking)

      payload = provider.send(:format_thinking, message)

      expect(payload[:reasoning_content]).to eq('Let me reason about this')
      expect(payload[:reasoning]).to eq('Let me reason about this')
    end

    it 'returns an empty payload for non-assistant messages' do
      message = RubyLLM::Message.new(role: :user, content: 'Hi')

      expect(provider.send(:format_thinking, message)).to eq({})
    end
  end

  describe '#format_content' do
    it 'rejects audio attachments that MiniMax does not accept' do
      attachment = RubyLLM::Attachment.new(StringIO.new('audio bytes'), filename: 'clip.mp3')

      expect do
        provider.send(:format_content, 'Transcribe this', [attachment])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end
end
