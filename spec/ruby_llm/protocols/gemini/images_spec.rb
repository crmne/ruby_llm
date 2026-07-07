# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Images do
  let(:protocol) do
    Object.new.tap do |object|
      object.extend(RubyLLM::Protocols::Gemini::Chat)
      object.extend(described_class)
    end
  end

  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }
  let(:audio_path) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }

  describe '#render_image_payload' do
    it 'keeps Imagen models on the image API' do
      payload = protocol.render_image_payload('a cat', model: 'imagen-4.0-generate-001', size: '1024x1024')

      expect(protocol.images_url).to eq('models/imagen-4.0-generate-001:predict')
      expect(payload).to eq(
        instances: [{ prompt: 'a cat' }],
        parameters: { sampleCount: 1 }
      )
    end

    it 'uses generateContent for Gemini image models' do
      payload = protocol.render_image_payload('a cat', model: 'gemini-2.5-flash-image', size: '1792x1024')

      expect(protocol.images_url).to eq('models/gemini-2.5-flash-image:generateContent')
      expect(payload).to eq(
        contents: [
          {
            role: 'user',
            parts: [{ text: 'a cat' }]
          }
        ],
        generationConfig: {
          responseModalities: %w[TEXT IMAGE]
        }
      )
    end

    it 'uses generateContent for Nano Banana aliases' do
      protocol.render_image_payload('a cat', model: 'nano-banana-pro', size: '1024x1024')

      expect(protocol.images_url).to eq('models/nano-banana-pro:generateContent')
    end

    it 'lets provider_options express Gemini-specific output options' do
      payload = protocol.render_image_payload(
        'a cat',
        model: 'gemini-2.5-flash-image',
        size: '1792x1024',
        provider_options: {
          generationConfig: {
            responseModalities: ['IMAGE'],
            candidateCount: 1
          }
        }
      )

      expect(payload[:generationConfig]).to eq(
        responseModalities: ['IMAGE'],
        candidateCount: 1
      )
    end

    it 'formats image references for Gemini image models' do
      payload = protocol.render_image_payload('edit this', model: 'gemini-2.5-flash-image', size: '1024x1024',
                                                           with: image_path)
      image_part = payload.dig(:contents, 0, :parts, 1)

      expect(image_part.dig(:inline_data, :mime_type)).to eq('image/png')
      expect(image_part.dig(:inline_data, :data)).to be_present
    end

    it 'rejects non-image references for Gemini image models' do
      expect do
        protocol.render_image_payload('edit this', model: 'gemini-2.5-flash-image', size: '1024x1024',
                                                   with: audio_path)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{Unsupported attachment type: audio/wav})
    end
  end

  describe '#parse_image_response' do
    it 'parses Imagen image API responses' do
      response = double(
        body: {
          'predictions' => [
            {
              'bytesBase64Encoded' => 'base64-image',
              'mimeType' => 'image/jpeg'
            }
          ]
        }
      )

      image = protocol.parse_image_response(response, model: 'imagen-4.0-generate-001')

      expect(image.data).to eq('base64-image')
      expect(image.mime_type).to eq('image/jpeg')
      expect(image.model).to eq('imagen-4.0-generate-001')
    end

    it 'parses Gemini generateContent image responses' do
      response = double(
        body: {
          'modelVersion' => 'gemini-2.5-flash-image-preview',
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => 'Here is an image.' },
                  {
                    'inlineData' => {
                      'mimeType' => 'image/png',
                      'data' => 'base64-image'
                    }
                  }
                ]
              }
            }
          ],
          'usageMetadata' => {
            'promptTokenCount' => 10,
            'cachedContentTokenCount' => 3,
            'candidatesTokenCount' => 7,
            'thoughtsTokenCount' => 2
          }
        }
      )

      image = protocol.parse_image_response(response, model: 'gemini-2.5-flash-image')

      expect(image.data).to eq('base64-image')
      expect(image.mime_type).to eq('image/png')
      expect(image.model).to eq('gemini-2.5-flash-image-preview')
      expect(image.tokens.input).to eq(7)
      expect(image.tokens.output).to eq(9)
    end

    it 'raises when Gemini generateContent returns no image' do
      response = double(
        body: {
          'candidates' => [
            {
              'content' => {
                'parts' => [{ 'text' => 'No image here.' }]
              }
            }
          ]
        }
      )

      expect do
        protocol.parse_image_response(response, model: 'gemini-2.5-flash-image')
      end.to raise_error(RubyLLM::Error, 'Unexpected response format from Gemini image generation API')
    end
  end

  describe '#validate_paint_inputs!' do
    it 'rejects masks for Gemini image models' do
      protocol.instance_variable_set(:@model, 'gemini-2.5-flash-image')

      expect do
        protocol.send(:validate_paint_inputs!, with: image_path, mask: image_path)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /Unsupported attachment type: image mask/)
    end
  end

  describe RubyLLM::Providers::VertexAI::Gemini do
    let(:vertex_provider) { double }
    let(:vertex_protocol) do
      described_class.allocate.tap do |object|
        object.instance_variable_set(:@provider, vertex_provider)
      end
    end

    it 'uses Vertex model paths for Gemini image models' do
      vertex_protocol.instance_variable_set(:@model, 'gemini-3-pro-image')
      allow(vertex_provider).to receive(:model_path).with('gemini-3-pro-image').and_return(
        'projects/test/locations/us/publishers/google/models/gemini-3-pro-image'
      )

      expect(vertex_protocol.images_url).to eq(
        'projects/test/locations/us/publishers/google/models/gemini-3-pro-image:generateContent'
      )
    end

    it 'uses Vertex model paths for Imagen models' do
      vertex_protocol.instance_variable_set(:@model, 'imagen-4.0-generate-001')
      allow(vertex_provider).to receive(:model_path).with('imagen-4.0-generate-001').and_return(
        'projects/test/locations/us/publishers/google/models/imagen-4.0-generate-001'
      )

      expect(vertex_protocol.images_url).to eq(
        'projects/test/locations/us/publishers/google/models/imagen-4.0-generate-001:predict'
      )
    end
  end
end
