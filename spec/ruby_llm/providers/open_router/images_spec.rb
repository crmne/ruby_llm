# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Images do
  let(:images_module) { described_class }

  describe '.images_url' do
    it 'returns the chat completions endpoint' do
      expect(images_module.images_url).to eq('chat/completions')
    end
  end

  describe '.render_image_payload' do
    it 'renders a chat completion payload with image modality' do
      payload = images_module.render_image_payload('a cute cat', model: 'test-model', size: '1024x1024')

      expect(payload[:model]).to eq('test-model')
      expect(payload[:messages]).to eq([{ role: 'user', content: 'a cute cat' }])
      expect(payload[:modalities]).to eq(%w[image text])
    end

    it 'ignores size parameter and logs debug message' do
      allow(RubyLLM.logger).to receive(:debug)
      images_module.render_image_payload('a cute cat', model: 'test-model', size: '512x512')
      expect(RubyLLM.logger).to have_received(:debug).with(/Ignoring size/)
    end
  end

  describe '.parse_image_response' do
    context 'with base64 data URL response' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => {
              'role' => 'assistant',
              'content' => 'Here is an image of a cat',
              'images' => [{
                'type' => 'image_url',
                'image_url' => {
                  'url' => 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAE='
                }
              }]
            }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'parses base64 image data from response' do
        image = images_module.parse_image_response(response, model: 'test-model')

        expect(image).to be_a(RubyLLM::Image)
        expect(image.base64?).to be(true)
        expect(image.data).to eq('iVBORw0KGgoAAAANSUhEUgAAAAE=')
        expect(image.mime_type).to eq('image/png')
        expect(image.model_id).to eq('test-model')
      end
    end

    context 'with jpeg image data URL' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => {
              'images' => [{
                'image_url' => { 'url' => 'data:image/jpeg;base64,/9j/4AAQSkZJRg==' }
              }]
            }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'parses jpeg image data' do
        image = images_module.parse_image_response(response, model: 'test-model')

        expect(image.mime_type).to eq('image/jpeg')
        expect(image.data).to eq('/9j/4AAQSkZJRg==')
      end
    end

    context 'with direct url field (alternative format)' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => {
              'images' => [{ 'url' => 'data:image/png;base64,abc123' }]
            }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'parses image from direct url field' do
        image = images_module.parse_image_response(response, model: 'test-model')

        expect(image.data).to eq('abc123')
      end
    end

    context 'with regular URL response' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => {
              'images' => [{
                'image_url' => { 'url' => 'https://example.com/image.png' }
              }]
            }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'creates image with URL instead of base64 data' do
        image = images_module.parse_image_response(response, model: 'test-model')

        expect(image.base64?).to be(false)
        expect(image.url).to eq('https://example.com/image.png')
        expect(image.mime_type).to eq('image/png')
      end
    end

    context 'with missing images in response' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => { 'content' => 'Sorry, I cannot generate images' }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'raises an error' do
        expect do
          images_module.parse_image_response(response, model: 'test-model')
        end.to raise_error(RubyLLM::Error, /Unexpected response format/)
      end
    end

    context 'with empty images array' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => { 'images' => [] }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'raises an error' do
        expect do
          images_module.parse_image_response(response, model: 'test-model')
        end.to raise_error(RubyLLM::Error, /Unexpected response format/)
      end
    end

    context 'with invalid data URL format' do
      let(:response_body) do
        {
          'choices' => [{
            'message' => {
              'images' => [{
                'image_url' => { 'url' => 'data:invalid-format' }
              }]
            }
          }]
        }
      end
      let(:response) { instance_double(Faraday::Response, body: response_body) }

      it 'raises an error for invalid data URL' do
        expect do
          images_module.parse_image_response(response, model: 'test-model')
        end.to raise_error(RubyLLM::Error, /Invalid data URL format/)
      end
    end
  end
end
