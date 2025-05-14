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
        image = RubyLLM.edit(prompt, with: { image: 'spec/fixtures/ruby.png' }, model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        save_and_verify_image image
      end

      it 'rejects edits with a non-PNG local file' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'spec/fixtures/ruby.wav' }, model: model)
        end.to raise_error(RubyLLM::BadRequestError, /Invalid image file or mode for image 0/)
      end

      it 'rejects edits with a non-existent local file' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'spec/fixtures/nonexistent.png' }, model: model)
        end.to raise_error(Errno::ENOENT, /No such file or directory/)
      end

      it 'customizes image output' do
        image = RubyLLM.edit(prompt, with: { image: 'spec/fixtures/ruby.png' }, model: model,
                                     options: { size: '1024x1024', quality: 'low' })
        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        expect(image.usage['output_tokens']).to eq(272)
      end
    end

    context 'with remote URLs' do
      it 'supports image edits with a valid remote PNG URL' do
        image = RubyLLM.edit(prompt, with: { image: 'https://paolino.me/images/rubyllm-1.0.png' }, model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        expect(image.usage).to eq({
                                    'input_tokens' => 362,
                                    'input_tokens_details' => { 'image_tokens' => 323, 'text_tokens' => 39 },
                                    'output_tokens' => 4160,
                                    'total_tokens' => 4522
                                  })
        expect(image.total_cost).to eq(0.17002)
        expect(image.input_cost).to eq(0.00362)
        expect(image.output_cost).to eq(0.1664)
        save_and_verify_image image
      end

      it 'rejects edits with a URL having invalid content type' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'https://rubyllm.com/assets/images/logotype.svg' }, model: model)
        end.to raise_error(RubyLLM::BadRequestError, /unsupported mimetype/)
      end

      it 'rejects edits with a URL that returns 404' do
        expect do
          RubyLLM.edit(prompt, with: { image: 'https://rubyllm.com/some-asset-that-does-not-exist.png' }, model: model)
        end.to raise_error(OpenURI::HTTPError, /404 Not Found/)
      end
    end
  end
end
