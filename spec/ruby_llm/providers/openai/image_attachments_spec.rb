# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::ImageAttachments do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.format' do
    it 'returns faraday::multipart compatible format for a single image URL' do
      attachments = described_class.new('https://paolino.me/images/rubyllm-1.0.png')

      atts = attachments.format
      expect(atts).to be_a(Array)
      expect(atts.length).to eq(1)
      expect(atts.first).to be_a(Faraday::Multipart::FilePart)
    end

    it 'returns faraday::multipart compatible format for multiple image URLs' do
      attachments = described_class.new(['https://paolino.me/images/rubyllm-1.0.png', 'https://paolino.me/images/rubyllm-1.0.png'])

      atts = attachments.format
      expect(atts).to be_a(Array)
      expect(atts.length).to eq(2)
      expect(atts.first).to be_a(Faraday::Multipart::FilePart)
      expect(atts.last).to be_a(Faraday::Multipart::FilePart)
    end
  end
end
