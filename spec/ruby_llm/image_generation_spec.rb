# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe RubyLLM::Image do
  include_context 'with configured RubyLLM'

  describe 'basic functionality' do
    it 'openai/dall-e-3 can paint images' do
      image = RubyLLM.paint('a siamese cat', model: 'dall-e-3')

      expect(image.base64?).to be(false)
      expect(image.url).to start_with('https://')
      expect(image.mime_type).to include('image')
      expect(image.revised_prompt).to include('cat')
      expect(image.model_id).to eq('dall-e-3')

      save_and_verify_image image
    end

    it 'openai/dall-e-3 supports custom sizes' do
      image = RubyLLM.paint('a siamese cat', size: '1792x1024', model: 'dall-e-3')

      expect(image.base64?).to be(false)
      expect(image.url).to start_with('https://')
      expect(image.mime_type).to include('image')
      expect(image.revised_prompt).to include('cat')

      save_and_verify_image image
    end

    it 'gemini/imagen-3.0-generate-002 can paint images' do
      image = RubyLLM.paint('a siamese cat', model: 'imagen-3.0-generate-002')

      expect(image.base64?).to be(true)
      expect(image.data).to be_present
      expect(image.mime_type).to include('image')

      save_and_verify_image image
    end

    it 'validates model existence' do
      expect do
        RubyLLM.paint('a cat', model: 'invalid-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'openai/gpt-image-1 can paint images' do
      image = RubyLLM.paint('a siamese cat', model: 'gpt-image-1')

      expect(image.base64?).to be(true)
      expect(image.data).to be_present
      expect(image.mime_type).to include('image')
      expect(image.model_id).to eq('gpt-image-1')

      save_and_verify_image image
    end
  end
end
