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
  end
end
