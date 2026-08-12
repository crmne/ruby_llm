# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Cohere::Media do
  let(:image) { RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__)) }
  let(:text_file) { RubyLLM::Attachment.new(File.expand_path('../../../fixtures/facts.txt', __dir__)) }
  let(:pdf) { RubyLLM::Attachment.new(File.expand_path('../../../fixtures/sample.pdf', __dir__)) }

  describe '.format_content' do
    it 'renders text as a text block' do
      expect(described_class.format_content('Describe this image')).to eq(
        [{ type: 'text', text: 'Describe this image' }]
      )
    end

    it 'renders images as base64 image_url blocks' do
      block = described_class.format_content(nil, [image]).first

      expect(block[:type]).to eq('image_url')
      expect(block[:image_url][:url]).to start_with('data:image/png;base64,')
    end

    it 'passes remote images through by URL' do
      remote = RubyLLM::Attachment.new('https://cohere.com/favicon-32x32.png')

      expect(described_class.format_content(nil, [remote])).to eq(
        [{ type: 'image_url', image_url: { url: 'https://cohere.com/favicon-32x32.png' } }]
      )
    end

    it 'inlines text attachments' do
      blocks = described_class.format_content('Who created Ruby?', [text_file])

      expect(blocks.length).to eq(2)
      expect(blocks.last[:text]).to include('facts.txt')
    end

    # Text attachments become top-level documents when citations are on.
    it 'leaves text attachments out of the content when citations are on' do
      blocks = described_class.format_content('Who created Ruby?', [text_file], citations: true)

      expect(blocks).to eq([{ type: 'text', text: 'Who created Ruby?' }])
    end

    it 'rejects attachment types the chat endpoint does not accept' do
      expect { described_class.format_content(nil, [pdf]) }
        .to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  describe '.format_documents' do
    it 'numbers documents the way Cohere numbers its own' do
      message = RubyLLM::Message.new(role: :user, content: 'Who created Ruby?', attachments: [text_file])

      documents = described_class.format_documents([message])

      expect(documents.length).to eq(1)
      expect(documents.first[:id]).to eq('doc:0')
      expect(documents.first[:data][:title]).to eq('facts.txt')
      expect(documents.first[:data][:text]).to include('Ruby')
    end

    it 'ignores images' do
      message = RubyLLM::Message.new(role: :user, content: 'What is this?', attachments: [image])

      expect(described_class.format_documents([message])).to be_empty
      expect(described_class.documents?([message])).to be(false)
    end
  end
end
