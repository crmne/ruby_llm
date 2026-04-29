# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

def save_and_verify_image(image)
  temp_file = Tempfile.new(['image', '.png'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = image.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.exist?(temp_path)).to be(true)

    file_size = File.size(temp_path)
    expect(file_size).to be > 1000 # Any real image should be larger than 1KB
  ensure
    File.delete(temp_path)
  end
end

RSpec.describe RubyLLM::Image do
  include_context 'with configured RubyLLM'

  def image_path
    File.expand_path('../fixtures/ruby.png', __dir__)
  end

  def audio_path
    File.expand_path('../fixtures/ruby.wav', __dir__)
  end

  def prompt
    'turn the logo to green'
  end

  def model
    'gpt-image-1'
  end

  def invalid_content_type_url
    'https://rubyllm.com/assets/images/logotype.svg'
  end

  def missing_remote_image_url
    'https://rubyllm.com/some-asset-that-does-not-exist.png'
  end

  describe 'basic functionality' do
    IMAGE_GENERATION_MODELS.each do |model_info|
      provider = model_info[:provider]
      model = model_info[:model]

      it "#{provider}/#{model} can paint images" do
        image = RubyLLM.paint('a siamese cat', model: model, provider: provider)

        expect(image.mime_type).to include('image')
        expect(image.model_id).to eq(model)

        save_and_verify_image image
      end

      next unless model_info[:supports_size]

      it "#{provider}/#{model} supports custom sizes" do
        image = RubyLLM.paint('a siamese cat', size: '1792x1024', model: model, provider: provider)

        expect(image.mime_type).to include('image')
        expect(image.model_id).to eq(model)

        save_and_verify_image image
      end
    end

    it 'validates model existence' do
      expect do
        RubyLLM.paint('a cat', model: 'invalid-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'gpt-image-1 supports image edits with multiple images' do
      image = RubyLLM.paint(prompt, model: model, with: [image_path, image_path])

      expect(image.base64?).to be(true)
      expect(image.mime_type).to eq('image/png')
      expect(image.model_id).to eq(model)
      expect(image.usage.dig('input_tokens_details', 'image_tokens')).to be > 0

      save_and_verify_image image
    end
  end

  describe 'edit functionality' do
    context 'with local files' do
      it 'supports image edits with a valid local PNG' do
        image = RubyLLM.paint(prompt, with: image_path, model: model)

        expect(image.base64?).to be(true)
        expect(image.data).to be_present
        expect(image.mime_type).to eq('image/png')
        expect(image.model_id).to eq(model)
        expect(image.usage.dig('input_tokens_details', 'image_tokens')).to be > 0
        expect(image.to_blob.bytesize).to be_positive
      end

      it 'rejects edits with a non-png local file' do
        expect do
          RubyLLM.paint(prompt, with: audio_path, model: model)
        end.to raise_error(RubyLLM::UnsupportedAttachmentError, /only supports image attachments/)
      end

      it 'customizes image output' do
        image = RubyLLM.paint(
          prompt,
          with: image_path,
          model: model,
          params: { size: '1024x1024', quality: 'low' }
        )

        expect(image.base64?).to be(true)
        expect(image.data).to be_present
        expect(image.mime_type).to eq('image/png')
        expect(image.usage['output_tokens']).to eq(272)
        expect(image.to_blob.bytesize).to be_positive
      end
    end

    context 'with remote URLs' do
      it 'rejects edits with a URL having invalid content type' do
        expect do
          RubyLLM.paint(prompt, with: invalid_content_type_url, model: model)
        end.to raise_error(RubyLLM::BadRequestError, /unsupported mimetype/)
      end

      it 'rejects edits with a URL that returns 404' do
        expect do
          RubyLLM.paint(prompt, with: missing_remote_image_url, model: model)
        end.to raise_error(Faraday::ResourceNotFound)
      end
    end
  end
end
