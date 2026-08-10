# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Images do
  describe '.render_image_payload' do
    it 'drops the size parameter xAI rejects' do
      payload = described_class.render_image_payload('a cute cat', model: 'grok-imagine-image', size: '1024x1024')

      expect(payload).to eq(model: 'grok-imagine-image', prompt: 'a cute cat')
    end

    it 'merges provider options' do
      payload = described_class.render_image_payload('a cute cat', model: 'grok-imagine-image', size: nil,
                                                                   provider_options: { n: 2 })

      expect(payload[:n]).to eq(2)
    end

    it 'renders reference images as typed data URIs for the edits endpoint' do
      image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)
      payload = described_class.render_image_payload('combine the logos', model: 'grok-imagine-image-quality',
                                                                          size: nil, with: [image_path])

      expect(payload[:images].length).to eq(1)
      expect(payload[:images].first[:type]).to eq('image_url')
      expect(payload[:images].first[:url]).to start_with('data:image/png;base64,')
    end

    it 'passes remote reference images through as URLs' do
      payload = described_class.render_image_payload('combine the logos', model: 'grok-imagine-image-quality',
                                                                          size: nil,
                                                                          with: 'https://example.com/logo.png')

      expect(payload[:images]).to eq([{ type: 'image_url', url: 'https://example.com/logo.png' }])
    end
  end

  describe '.images_url' do
    it 'targets the edits endpoint when reference images are given' do
      expect(described_class.images_url(with: 'logo.png')).to eq('images/edits')
      expect(described_class.images_url).to eq('images/generations')
    end
  end

  describe '.validate_paint_inputs!' do
    it 'rejects masks with a clear error' do
      expect do
        described_class.validate_paint_inputs!(with: 'logo.png', mask: 'mask.png')
      end.to raise_error(RubyLLM::Error, /mask/)
    end
  end
end
