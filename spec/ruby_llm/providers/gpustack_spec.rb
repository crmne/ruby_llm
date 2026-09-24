# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack do
  let(:provider) { described_class::ChatCompletions.allocate }

  describe '#format_messages' do
    it 'includes empty content when replaying a thinking-only assistant message' do
      thinking = RubyLLM::Thinking.new(text: 'I should reason first')
      message = RubyLLM::Message.new(role: :assistant, content: nil, thinking: thinking)

      formatted = provider.send(:format_messages, [message])

      expect(formatted.first[:content]).to eq('')
      expect(formatted.first[:reasoning_content]).to eq('I should reason first')
    end
  end

  describe '#format_content' do
    it 'raises an actionable error for unsupported document attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        provider.send(:format_content, 'Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'passes remote image URLs through instead of downloading and re-encoding them' do
      attachment = RubyLLM::Attachment.new('https://example.com/photo.png')

      formatted = provider.send(:format_content, 'Describe this image', [attachment])

      expect(formatted.last).to eq(
        type: 'image_url',
        image_url: { url: 'https://example.com/photo.png', detail: 'auto' }
      )
    end
  end
end
