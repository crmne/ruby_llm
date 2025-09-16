# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Media do
  include_context 'with configured RubyLLM'

  let(:media) do
    Object.new.tap do |obj|
      obj.extend(described_class)
    end
  end

  describe '#sanitize_filename' do
    it 'removes disallowed characters and collapses whitespace' do
      expect(media.send(:sanitize_filename, 'my @weird\nfile (1)[a].pdf')).to eq('my weirdnfile (1)[a]pdf')
      expect(media.send(:sanitize_filename, '  spaced    name  ')).to eq('spaced name')
    end

    it 'returns nil for empty result' do
      expect(media.send(:sanitize_filename, '***')).to be_nil
    end
  end

  describe 'converse parts formatting' do
    it 'formats text' do
      expect(media.send(:format_text, 'hi')).to eq({ 'text' => 'hi' })
    end

    it 'formats image' do
      img = RubyLLM::Attachment.new(StringIO.new('data'), filename: 'img.png')
      allow(img).to receive_messages(mime_type: 'image/png', encoded: 'BASE64')

      part = media.send(:format_image, img)
      expect(part['image']['format']).to eq('png')
      expect(part['image']['name']).to eq('imgpng')
      expect(part['image']['source']).to eq({ 'bytes' => 'BASE64' })
    end

    it 'formats document for pdf' do
      pdf = RubyLLM::Attachment.new(StringIO.new('pdfdata'), filename: 'a.pdf')
      allow(pdf).to receive_messages(mime_type: 'application/pdf', encoded: 'BASE64PDF')

      part = media.send(:format_document, pdf)
      expect(part['document']['format']).to eq('pdf')
      expect(part['document']['name']).to eq('apdf')
      expect(part['document']['source']).to eq({ 'bytes' => 'BASE64PDF' })
    end

    it 'adds counter prefix when multiple attachments' do
      content = RubyLLM::Content.new('hi')
      img1 = RubyLLM::Attachment.new(StringIO.new('d1'), filename: '1.png')
      img2 = RubyLLM::Attachment.new(StringIO.new('d2'), filename: '2.png')
      allow(img1).to receive_messages(mime_type: 'image/png', encoded: 'B1')
      allow(img2).to receive_messages(mime_type: 'image/png', encoded: 'B2')
      content.instance_variable_set(:@attachments, [img1, img2])

      parts = media.send(:format_content, content)
      expect(parts[0]).to eq({ 'text' => 'hi' })
      expect(parts[1]['image']['name']).to start_with('1 ')
      expect(parts[2]['image']['name']).to start_with('2 ')
    end
  end
end
