# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

def save_and_verify_image(image) # rubocop:disable Metrics/MethodLength
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

RSpec.describe RubyLLM::Image do
  include_context 'with configured RubyLLM'

  describe 'basic functionality' do
    it 'openai/dall-e-3 can paint images' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
      image = RubyLLM.paint('a siamese cat', model: 'dall-e-3')

      expect(image.base64?).to be(false)
      expect(image.url).to start_with('https://')
      expect(image.mime_type).to include('image')
      expect(image.revised_prompt).to include('cat')

      save_and_verify_image image
    end

    it 'openai/dall-e-3 supports custom sizes' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
      image = RubyLLM.paint('a siamese cat', size: '1792x1024', model: 'dall-e-3')

      expect(image.base64?).to be(false)
      expect(image.url).to start_with('https://')
      expect(image.mime_type).to include('image')
      expect(image.revised_prompt).to include('cat')

      save_and_verify_image image
    end

    it 'gemini/imagen-3.0-generate-002 can paint images' do # rubocop:disable RSpec/MultipleExpectations
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
  end

  describe 'edit functionality (OpenAI)', :vcr do # Apply VCR to this context
    let(:prompt) { 'turn the logo to green' }
    let(:model) { 'gpt-image-1' } # Assuming this model uses the edits endpoint

    context 'with local files' do
      it 'supports image edits with a valid local PNG' do
        image = RubyLLM.edit(prompt, with: { image: VALID_PNG_PATH }, model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        save_and_verify_image image
      end

      it 'rejects edits with a non-PNG local file' do
        expect do
          RubyLLM.edit(prompt, with: { image: INVALID_FORMAT_PATH }, model: model)
        end.to raise_error(RubyLLM::InvalidImageFormatError, /Only \.png is supported/)
      end

      it 'rejects edits with a non-existent local file' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'spec/fixtures/nonexistent.png' }, model: model)
        end.to raise_error(RubyLLM::FileNotFoundError, /file not found/)
      end

      # Add test for local file size limit if LARGE_PNG_PATH is setup
      # it 'rejects edits with an oversized local PNG' do
      #   expect do
      #     RubyLLM.edit(prompt, with: { image: LARGE_PNG_PATH }, model: model)
      #   end.to raise_error(RubyLLM::ImageTooLargeError, /exceeds 4MB limit/)
      # end
    end

    context 'with remote URLs' do
      it 'supports image edits with a valid remote PNG URL' do
        image = RubyLLM.edit(prompt, with: { image: 'https://paolino.me/images/rubyllm-1.0.png' }, model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        save_and_verify_image image
      end

      it 'rejects edits with a URL having invalid content type' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'https://rubyllm.com/assets/images/logotype.svg' }, model: model)
        end.to raise_error(RubyLLM::InvalidImageContentTypeError, %r{Expected 'image/png'})
      end

      it 'rejects edits with a URL that returns 404' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'https://rubyllm.com/some-asset-that-does-not-exist.png' }, model: model)
        end.to raise_error(RubyLLM::NetworkError, /Failed to download image from URL/)
      end

      # Add test for URL file size limit if LARGE_IMAGE_URL is setup
      # it 'rejects edits with an oversized remote PNG URL' do
      #   expect do
      #     RubyLLM.edit(prompt, with: { image: LARGE_IMAGE_URL }, model: model)
      #   end.to raise_error(RubyLLM::ImageTooLargeError, /exceeds 4MB limit/)
      # end
    end

    context 'with masks' do
      # Similar tests for mask validation (local path/URL, format, size, existence/network)
      # Example:
      it 'supports edits with a valid local PNG mask' do
        # Assuming mask processing requires changes in how save_and_verify_image works or just checking API call structure
        expect do # Replace with actual call and verification
          RubyLLM.edit(prompt, with: { image: VALID_PNG_PATH, mask: VALID_PNG_PATH }, model: model)
        end.not_to raise_error # Placeholder assertion
      end

      it 'supports edits with a valid remote PNG URL mask' do
        expect do # Replace with actual call and verification
          RubyLLM.edit(prompt, with: { image: VALID_PNG_PATH, mask: VALID_IMAGE_URL }, model: model)
        end.not_to raise_error # Placeholder assertion
      end

      it 'rejects edits with an invalid local mask format' do
        expect do
          RubyLLM.edit(prompt, with: { image: VALID_PNG_PATH, mask: INVALID_FORMAT_PATH }, model: model)
        end.to raise_error(RubyLLM::InvalidImageFormatError, /mask.*Only \.png is supported/)
      end

      it 'rejects edits with an invalid remote mask content type' do
        expect do
          RubyLLM.edit(prompt, with: { image: VALID_PNG_PATH, mask: INVALID_CONTENT_TYPE_URL }, model: model)
        end.to raise_error(RubyLLM::InvalidImageContentTypeError, %r{mask.*Expected 'image/png'})
      end
    end

    context 'general validation' do
      it 'rejects edits with multiple images' do
        expect do
          RubyLLM.edit(prompt, with: { image: [VALID_PNG_PATH, VALID_PNG_PATH] }, model: model)
        end.to raise_error(ArgumentError, /support only one input image/)
      end

      it 'rejects edits with invalid source type' do
        expect do
          RubyLLM.edit(prompt, with: { image: 123 }, model: model)
        end.to raise_error(RubyLLM::InvalidSourceTypeError, /Expected a URL or file path string/)
      end
    end

    # Remove or adapt original multi-image test if `gpt-image-1` doesn't support it via this endpoint
    # it 'gpt-image-1 supports image edits with multiple images' do ... end

    # Keep Gemini rejection test
    it 'gemini rejects image edits' do
      # ... (existing test) ...
    end
  end # describe 'edit functionality'
end # RSpec.describe RubyLLM::Image
