# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:model) { 'gpt-4.1-nano' }
  let(:chat) { Chat.create!(model: model) }

  def mock_action_text(plain_text)
    instance_double(ActionText::RichText).tap do |mock|
      allow(mock).to receive(:to_plain_text).and_return(plain_text)
    end
  end

  def create_message_with_action_text(content_text)
    message = chat.messages.create!(role: :user)
    action_text_content = mock_action_text(content_text)
    allow(message).to receive(:content).and_return(action_text_content)
    [message, action_text_content]
  end

  describe 'Action Text content extraction' do
    context 'when content responds to to_plain_text' do
      it 'extracts plain text from Action Text content' do
        message, action_text_content = create_message_with_action_text('This is plain text')

        llm_message = message.to_llm

        expect(action_text_content).to have_received(:to_plain_text)
        expect(llm_message.content).to eq('This is plain text')
      end
    end

    context 'when content is a regular string' do
      it 'returns content unchanged' do
        message = chat.messages.create!(role: :user, content: 'Regular text content')

        expect(message.to_llm.content).to eq('Regular text content')
      end
    end

    context 'when Action Text content has attachments' do
      let(:test_attachment) do
        { io: StringIO.new('test data'), filename: 'test.txt', content_type: 'text/plain' }
      end

      it 'combines Action Text with attachments into RubyLLM::Content' do
        message, action_text_content = create_message_with_action_text('Rich text with attachment')
        message.attachments.attach(test_attachment)

        llm_message = message.to_llm

        expect(action_text_content).to have_received(:to_plain_text)
        expect(llm_message.content).to be_a(RubyLLM::Content)
        expect(llm_message.content.text).to eq('Rich text with attachment')
        expect(llm_message.content.attachments.first.mime_type).to eq('text/plain')
      end
    end
  end
end
