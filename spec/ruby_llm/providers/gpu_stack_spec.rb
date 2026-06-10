# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack do
  let(:provider) { described_class.allocate }

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
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        provider.send(:format_content, content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end
  end
end
