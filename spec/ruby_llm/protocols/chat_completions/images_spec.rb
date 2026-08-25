# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Images do
  describe '#render_image_payload' do
    it 'asks for one image by default' do
      payload = described_class.render_image_payload('a cat', model: 'gpt-image-1', size: '1024x1024')

      expect(payload[:n]).to eq(1)
    end

    it 'asks for as many images as requested' do
      payload = described_class.render_image_payload('a cat', model: 'gpt-image-1', size: '1024x1024', count: 4)

      expect(payload[:n]).to eq(4)
    end

    it 'carries the count into edit requests' do
      payload = described_class.render_image_payload(
        'make it green', model: 'gpt-image-1', size: '1024x1024', count: 2,
                         with: 'https://example.com/logo.png'
      )

      expect(payload[:n]).to eq(2)
    end

    it 'sends the size the caller asked for when editing' do
      %w[gpt-image-1 gpt-image-2 chatgpt-image-1].each do |model|
        payload = described_class.render_image_payload(
          'make it green', model: model, size: '1536x1024', with: 'https://example.com/logo.png'
        )

        expect(payload[:size]).to eq('1536x1024')
      end
    end

    it 'sends no size when the caller chose none' do
      payload = described_class.render_image_payload(
        'make it green', model: 'gpt-image-1', size: nil, with: 'https://example.com/logo.png'
      )

      expect(payload).not_to have_key(:size)
    end
  end

  describe '#parse_image_responses' do
    let(:response) do
      instance_double(
        Faraday::Response,
        body: {
          'data' => [
            { 'b64_json' => 'first-image' },
            { 'b64_json' => 'second-image' }
          ],
          'usage' => { 'input_tokens' => 10, 'output_tokens' => 20 }
        }
      )
    end

    it 'returns every image the request generated' do
      images = described_class.parse_image_responses(response, model: 'gpt-image-1')

      expect(images.map(&:data)).to eq(%w[first-image second-image])
    end

    it 'bills the call once, on the first image' do
      images = described_class.parse_image_responses(response, model: 'gpt-image-1')

      expect(images.first.tokens.input).to eq(10)
      expect(images.last.tokens.input).to be_nil
    end

    it 'raises when the response carries no image' do
      empty = instance_double(Faraday::Response, body: { 'data' => [] })

      expect { described_class.parse_image_responses(empty, model: 'gpt-image-1') }
        .to raise_error(RubyLLM::Error, /Unexpected response format/)
    end
  end
end
