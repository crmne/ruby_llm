# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Images do
  let(:protocol) { RubyLLM::Providers::OpenRouter::ChatCompletions.allocate }
  let(:image_fixture) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  describe '#images_url' do
    it 'returns the unified images endpoint' do
      expect(protocol.send(:images_url)).to eq('images')
    end
  end

  describe '#render_image_payload' do
    it 'renders a generation payload' do
      payload = protocol.send(:render_image_payload, 'a cute cat', model: 'google/gemini-2.5-flash-image',
                                                                   size: '1024x1024')

      expect(payload).to eq(model: 'google/gemini-2.5-flash-image', prompt: 'a cute cat')
    end

    it 'merges provider options' do
      payload = protocol.send(:render_image_payload, 'a cute cat', model: 'google/gemini-2.5-flash-image', size: nil,
                                                                   provider_options: { aspect_ratio: '16:9' })

      expect(payload[:aspect_ratio]).to eq('16:9')
    end

    it 'sends reference images as input_references' do
      payload = protocol.send(:render_image_payload, 'make it green', model: 'google/gemini-2.5-flash-image', size: nil,
                                                                      with: image_fixture)

      reference = payload[:input_references].first
      expect(reference[:type]).to eq('image_url')
      expect(reference[:image_url][:url]).to start_with('data:image/png;base64,')
    end

    it 'passes reference URLs through untouched' do
      payload = protocol.send(:render_image_payload, 'make it green', model: 'google/gemini-2.5-flash-image', size: nil,
                                                                      with: 'https://example.com/logo.png')

      expect(payload[:input_references]).to eq(
        [{ type: 'image_url', image_url: { url: 'https://example.com/logo.png' } }]
      )
    end

    it 'rejects non-image references' do
      audio = File.expand_path('../../../fixtures/ruby.wav', __dir__)

      expect do
        protocol.send(:render_image_payload, 'make it green', model: 'google/gemini-2.5-flash-image', size: nil,
                                                              with: audio)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{audio/wav})
    end
  end

  describe '#validate_paint_inputs!' do
    it 'allows reference images' do
      expect { protocol.send(:validate_paint_inputs!, with: image_fixture, mask: nil) }.not_to raise_error
    end

    it 'rejects masks' do
      expect do
        protocol.send(:validate_paint_inputs!, with: image_fixture, mask: image_fixture)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /image mask/)
    end
  end

  describe '#parse_image_response' do
    let(:response_body) do
      {
        'created' => 0,
        'data' => [{ 'b64_json' => '/9j/4AAQSkZJRg==', 'media_type' => 'image/jpeg' }],
        'usage' => {
          'prompt_tokens' => 7,
          'completion_tokens' => 1120,
          'total_tokens' => 1127,
          'cost' => 0.0336,
          'is_byok' => false,
          'cost_details' => { 'upstream_inference_cost' => 0.0336 }
        }
      }
    end
    let(:response) { instance_double(Faraday::Response, body: response_body) }

    it 'parses the image and its usage' do
      image = protocol.send(:parse_image_response, response, model: 'google/gemini-2.5-flash-image')

      expect(image.base64?).to be(true)
      expect(image.data).to eq('/9j/4AAQSkZJRg==')
      expect(image.mime_type).to eq('image/jpeg')
      expect(image.model).to eq('google/gemini-2.5-flash-image')
      expect(image.tokens.input).to eq(7)
      expect(image.tokens.output).to eq(1120)
      expect(image.tokens.reported_cost).to eq(0.0336)
      expect(image.cost.total).to eq(0.0336)
    end

    it 'defaults the MIME type when the provider omits it' do
      response_body['data'].first.delete('media_type')

      image = protocol.send(:parse_image_response, response, model: 'google/gemini-2.5-flash-image')

      expect(image.mime_type).to eq('image/png')
    end

    it 'raises an error when no image data is returned' do
      empty = instance_double(Faraday::Response, body: { 'data' => [] })

      expect do
        protocol.send(:parse_image_response, empty, model: 'google/gemini-2.5-flash-image')
      end.to raise_error(RubyLLM::Error, /Unexpected response format/)
    end
  end
end
