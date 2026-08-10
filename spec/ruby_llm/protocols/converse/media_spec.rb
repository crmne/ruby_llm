# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Media do
  describe '.format_content' do
    it 'renders supported Office documents as Bedrock document blocks' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')

      rendered = described_class.format_content('Summarize this file', [attachment])

      expect(rendered.second).to eq(
        document: {
          format: 'docx',
          name: 'proposal',
          source: {
            bytes: Base64.strict_encode64('docx bytes')
          }
        }
      )
    end

    it 'renders provider-managed documents as S3 document blocks' do
      file = RubyLLM::UploadedFile.new(
        id: 's3://ruby-llm-test/uploads/report.pdf',
        uri: 's3://ruby-llm-test/uploads/report.pdf',
        filename: 'report.pdf',
        mime_type: 'application/pdf'
      )
      rendered = described_class.format_content('Summarize this file', RubyLLM::Attachment.wrap(file))

      expect(rendered.second).to eq(
        document: {
          format: 'pdf',
          name: 'report',
          source: {
            s3Location: {
              uri: 's3://ruby-llm-test/uploads/report.pdf'
            }
          }
        }
      )
    end

    it 'renders audio attachments as audio blocks' do
      attachment = RubyLLM::Attachment.new(StringIO.new('wav bytes'), filename: 'clip.wav')

      rendered = described_class.format_content('What is said?', [attachment])

      expect(rendered.second).to eq(
        audio: {
          format: 'wav',
          source: {
            bytes: Base64.strict_encode64('wav bytes')
          }
        }
      )
    end

    it 'renders video attachments as video blocks' do
      attachment = RubyLLM::Attachment.new(StringIO.new('mp4 bytes'), filename: 'clip.mp4')

      rendered = described_class.format_content('What is shown?', [attachment])

      expect(rendered.second).to eq(
        video: {
          format: 'mp4',
          source: {
            bytes: Base64.strict_encode64('mp4 bytes')
          }
        }
      )
    end

    it 'normalizes media formats to the names Bedrock accepts' do
      mov = RubyLLM::Attachment.new(StringIO.new('mov bytes'), filename: 'clip.mov')
      three_gp = RubyLLM::Attachment.new(StringIO.new('3gp bytes'), filename: 'clip.3gp')

      expect(described_class.format_content(nil, [mov]).first[:video][:format]).to eq('mov')
      expect(described_class.format_content(nil, [three_gp]).first[:video][:format]).to eq('three_gp')
    end

    it 'raises for audio formats Bedrock does not accept' do
      attachment = RubyLLM::Attachment.new(StringIO.new('amr bytes'), filename: 'clip.amr')

      expect do
        described_class.format_content(nil, [attachment])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'keeps text file formats as text blocks' do
      %w[csv txt md html json].each do |extension|
        attachment = RubyLLM::Attachment.new(StringIO.new('notes'), filename: "notes.#{extension}")

        rendered = described_class.format_content('Summarize this file', [attachment])

        expect(rendered.second).to eq(text: attachment.for_llm)
      end
    end

    it 'enables citations on document blocks when citations are requested' do
      attachment = RubyLLM::Attachment.new(StringIO.new('%PDF-1.4'), filename: 'report.pdf')

      rendered = described_class.format_content('Summarize this file', [attachment], citations: true)

      expect(rendered.second[:document][:citations]).to eq(enabled: true)
    end

    it 'renders text files as citable text documents when citations are requested' do
      attachment = RubyLLM::Attachment.new(StringIO.new('Matz created Ruby.'), filename: 'facts.txt')

      rendered = described_class.format_content('Who created Ruby?', [attachment], citations: true)

      expect(rendered.second).to eq(
        document: {
          format: 'txt',
          name: 'facts',
          source: { text: 'Matz created Ruby.' },
          citations: { enabled: true }
        }
      )
    end

    it 'enables citations on provider-managed documents when citations are requested' do
      file = RubyLLM::UploadedFile.new(
        id: 's3://ruby-llm-test/uploads/report.pdf',
        uri: 's3://ruby-llm-test/uploads/report.pdf',
        filename: 'report.pdf',
        mime_type: 'application/pdf'
      )

      rendered = described_class.format_content('Summarize this file', RubyLLM::Attachment.wrap(file),
                                                citations: true)

      expect(rendered.second[:document][:citations]).to eq(enabled: true)
    end

    it 'raises an actionable error for document formats Bedrock does not accept' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pptx bytes'), filename: 'deck.pptx')

      expect do
        described_class.format_content('Summarize this file', [attachment])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.presentationml.presentation}
      )
    end
  end
end
