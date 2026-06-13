# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Images do
  include_context 'with configured RubyLLM'

  # Build a host object that mixes in Images alongside Media so format_attachment
  # is reachable, mirroring how the real Gemini protocol composes its modules.
  let(:host) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Protocols::Gemini::Media)
      obj.extend(described_class)
    end
  end

  describe '#render_image_payload (Imagen with `with:`)' do
    it 'rejects image references for Imagen models' do
      expect do
        host.render_image_payload(
          'a cat',
          model: 'imagen-4.0-generate-001',
          size: '1024x1024',
          with: 'spec/fixtures/ruby.png'
        )
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /Imagen does not support image references/)
    end
  end

  describe '#parse_image_response (Imagen)' do
    it 'raises when the predictions entry has no bytesBase64Encoded field' do
      response = instance_double(Faraday::Response, body: { 'predictions' => [{}] })

      expect do
        host.parse_image_response(response, model: 'imagen-4.0-generate-001')
      end.to raise_error(RubyLLM::Error, /Unexpected response format/)
    end
  end

  describe '#render_image_payload (Gemini Image with unknown attachment type)' do
    it 'raises when an attachment has an unknown mime type' do
      fake_attachment = instance_double(
        RubyLLM::Attachment,
        type: :unknown,
        mime_type: 'application/x-unrecognized'
      )
      allow(RubyLLM::Attachment).to receive(:new).and_return(fake_attachment)

      expect do
        host.render_image_payload(
          'edit this',
          model: 'gemini-2.5-flash-image',
          size: '1024x1024',
          with: 'spec/fixtures/ruby.png'
        )
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /does not support attachment type/)
    end
  end

  describe '#render_image_payload (Gemini Image size: handling)' do
    it 'translates DALL-E-style WxH strings via SIZE_TO_ASPECT_RATIO' do
      payload = host.render_image_payload('a panda', model: 'gemini-2.5-flash-image', size: '1792x1024')

      expect(payload.dig(:generationConfig, :imageConfig, :aspectRatio)).to eq('16:9')
    end

    it 'passes native Gemini aspectRatio strings through unchanged' do
      %w[1:1 2:3 3:4 4:5 9:16 16:9 21:9].each do |ratio|
        payload = host.render_image_payload('a panda', model: 'gemini-2.5-flash-image', size: ratio)

        expect(payload.dig(:generationConfig, :imageConfig, :aspectRatio)).to eq(ratio)
      end
    end

    it 'defaults aspectRatio to 1:1 and logs a debug message for an unknown size string' do
      allow(RubyLLM.logger).to receive(:debug).and_yield

      payload = host.render_image_payload('a panda', model: 'gemini-2.5-flash-image', size: '999x999')

      expect(payload.dig(:generationConfig, :imageConfig, :aspectRatio)).to eq('1:1')
      expect(RubyLLM.logger).to have_received(:debug).at_least(:once)
    end
  end
end
