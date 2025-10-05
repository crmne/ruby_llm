# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

def save_and_verify_image(image)
  # Create a temp file to save to
  temp_file = Tempfile.new(['image', '.png'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = image.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.exist?(temp_path)).to be true

    file_size = File.size(temp_path)
    expect(file_size).to be > 1000 # Any real image should be larger than 1KB
  ensure
    # Clean up
    File.delete(temp_path)
  end
end

def save_and_verify_deferred_image(image)
  tries = 0

  begin
    save_and_verify_image image
  rescue RSpec::Expectations::ExpectationNotMetError => e
    tries += 1
    sleep 1
    retry if tries < 20
    raise e
  end
end

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

    it 'google/imagen-4-ultra, an official replicate model, can paint images' do
      image = RubyLLM.paint('a siamese cat', model: 'google/imagen-4-ultra', output_format: 'png')

      expect(image).to be_a(RubyLLM::DeferredImage)

      save_and_verify_deferred_image image
    end

    it 'prunaai/hidream-l1-fast, an unofficial replicate model, can paint images' do
      image = RubyLLM.paint('a siamese cat', model: 'prunaai/hidream-l1-fast', output_format: 'png')

      expect(image).to be_a(RubyLLM::DeferredImage)

      save_and_verify_deferred_image image
    end

    it 'fetches finished deferred images' do
      output_url = 'https://replicate.delivery/xezq/6qGn3LIY0MJmI9wxvoFLfZIY0sn7b8psftLM86DioJ7iIFcVA/tmpexunri3x.png'
      image = RubyLLM.image_from(output_url, provider: :replicate)

      expect(image).to be_a(described_class)
      expect(image.blob?).to be(true)

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
