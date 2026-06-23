# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Media do
  describe '.format_content' do
    it 'formats provider-managed files as input_file file_id parts' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')
      content = RubyLLM::Content.new('Summarize this file', file)

      formatted = described_class.format_content(content)

      expect(formatted.second).to eq(
        type: 'input_file',
        file_id: 'file_123'
      )
    end
  end
end
