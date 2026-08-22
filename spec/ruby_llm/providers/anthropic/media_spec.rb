# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Media do
  describe '.format_content' do
    let(:pdf_path) { File.join('spec', 'fixtures', 'sample.pdf') }

    it 'serializes RubyLLM::Content with attachments into Anthropic blocks' do
      content = RubyLLM::Content.new('Summarize this', pdf_path)

      blocks = described_class.format_content(content)

      expect(blocks).to all(be_a(Hash))
      expect(blocks.first).to include(type: 'text', text: 'Summarize this')
      document_block = blocks.detect { |block| block[:type] == 'document' }
      expect(document_block).to be_present
      expect(document_block[:source]).to include(type: 'base64', media_type: 'application/pdf')
      expect(document_block[:source][:data]).to be_present
    end

    it 'serializes a raw structured-output Hash into a JSON text block' do
      content = RubyLLM::Content::Raw.new({ 'name' => 'Sophie' })

      blocks = described_class.format_content(content)

      expect(blocks).to eq([{ type: 'text', text: '{"name":"Sophie"}' }])
    end

    it 'passes through a raw provider-typed block Hash verbatim' do
      raw_block = { type: 'text', text: 'hello', cache_control: { type: 'ephemeral' } }
      content = RubyLLM::Content::Raw.new(raw_block)

      expect(described_class.format_content(content)).to eq(raw_block)
    end

    it 'passes through raw block Arrays verbatim' do
      raw_blocks = [{ type: 'text', text: 'hello' }]
      content = RubyLLM::Content::Raw.new(raw_blocks)

      expect(described_class.format_content(content)).to eq(raw_blocks)
    end

    it 'raises an actionable error for unsupported Office documents' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        described_class.format_content(content)
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end
  end
end
