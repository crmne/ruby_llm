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
      expect(image.usage).to eq({
                                  'input_tokens' => 10,
                                  'input_tokens_details' => {
                                    'image_tokens' => 0,
                                    'text_tokens' => 10
                                  },
                                  'output_tokens' => 1056,
                                  'total_tokens' => 1066
                                })

      save_and_verify_image image
    end
  end

  describe 'edit functionality (OpenAI)', :vcr do # Apply VCR to this context
    let(:prompt) { 'turn the logo to green' }
    let(:model) { 'gpt-image-1' } # Assuming this model uses the edits endpoint

    it 'uses the right payload for image edits' do
      payload = RubyLLM::Providers::OpenAI::Images.render_edit_payload(
        'turn the logo to green', model: 'gpt-image-1',
                                  with: 'spec/fixtures/ruby.png', params: { size: '1024x1024', quality: 'low' }
      )

      expect(payload[:model]).to eq('gpt-image-1')
      expect(payload[:prompt]).to eq('turn the logo to green')
      expect(payload[:n]).to eq(1)
      expect(payload[:size]).to eq('1024x1024')
      expect(payload[:quality]).to eq('low')

      # Verify that the image part contains a Faraday::UploadIO with the correct content
      expect(payload[:image]).to be_an(Array)
      expect(payload[:image].length).to eq(1)

      upload_io = payload[:image].first
      expect(upload_io).to be_a(Faraday::UploadIO)
      expect(upload_io.content_type).to eq('image/png')
      expect(upload_io.original_filename).to eq('ruby.png')

      # Verify the actual file content matches
      expected_content = File.read('spec/fixtures/ruby.png', mode: 'rb')
      actual_content = upload_io.io.read
      upload_io.io.rewind # Reset the IO position for potential future reads

      # Ensure both strings use the same encoding for comparison
      actual_content.force_encoding('ASCII-8BIT')
      expect(actual_content).to eq(expected_content)
    end

    it 'uses the right payload for editing multiple images' do
      payload = RubyLLM::Providers::OpenAI::Images.render_edit_payload(
        'turn the logo to green', model: 'gpt-image-1',
                                  with: ['spec/fixtures/ruby.png', 'spec/fixtures/ruby_with_blue.png'],
                                  params: { size: '1024x1024', quality: 'low' }
      )
      expect(payload[:image]).to be_an(Array)
      expect(payload[:image].length).to eq(2)

      upload_io = payload[:image].first
      expect(upload_io).to be_a(Faraday::UploadIO)
      expect(upload_io.content_type).to eq('image/png')
      expect(upload_io.original_filename).to eq('ruby.png')

      expected_content = File.read('spec/fixtures/ruby.png', mode: 'rb')
      actual_content = upload_io.io.read
      upload_io.io.rewind # Reset the IO position for potential future reads
      actual_content.force_encoding('ASCII-8BIT')
      expect(actual_content).to eq(expected_content)

      upload_io = payload[:image].last
      expect(upload_io).to be_a(Faraday::UploadIO)
      expect(upload_io.content_type).to eq('image/png')
      expect(upload_io.original_filename).to eq('ruby_with_blue.png')

      expected_content = File.read('spec/fixtures/ruby_with_blue.png', mode: 'rb')
      actual_content = upload_io.io.read
      upload_io.io.rewind # Reset the IO position for potential future reads
      actual_content.force_encoding('ASCII-8BIT')
      expect(actual_content).to eq(expected_content)
    end

    context 'with local files' do
      it 'supports image edits with a valid local PNG' do
        image = RubyLLM.paint(prompt, with: 'spec/fixtures/ruby.png', model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        save_and_verify_image image
      end

      it 'rejects edits with a non-PNG local file' do
        expect do
          RubyLLM.paint(prompt, with: 'spec/fixtures/ruby.wav', model: model)
        end.to raise_error(RubyLLM::BadRequestError, /Invalid image file or mode for image 0/)
      end

      it 'rejects edits with a non-existent local file' do
        expect do
          RubyLLM.paint(prompt, with: 'spec/fixtures/nonexistent.png', model: model)
        end.to raise_error(Errno::ENOENT, /No such file or directory/)
      end

      it 'customizes image output' do
        image = RubyLLM.paint(prompt, with: 'spec/fixtures/ruby.png', model: model,
                                      params: { size: '1024x1024', quality: 'low' })
        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        expect(image.usage['output_tokens']).to eq(272)
      end
    end

    context 'with remote URLs' do
      it 'supports image edits with a valid remote PNG URL' do
        image = RubyLLM.paint(prompt, with: 'https://paolino.me/images/rubyllm-1.0.png', model: model)

        expect(image.base64?).to be(true)
        expect(image.mime_type).to eq('image/png')
        expect(image.usage).to eq({
                                    'input_tokens' => 362,
                                    'input_tokens_details' => { 'image_tokens' => 323, 'text_tokens' => 39 },
                                    'output_tokens' => 4160,
                                    'total_tokens' => 4522
                                  })
        expect(image.total_cost).to eq(0.16821)
        expect(image.input_cost).to eq(0.00181)
        expect(image.output_cost).to eq(0.1664)
        save_and_verify_image image
      end

      it 'rejects edits with a URL having invalid content type' do
        expect do
          RubyLLM.paint(prompt, with: 'https://rubyllm.com/assets/images/logotype.svg', model: model)
        end.to raise_error(RubyLLM::BadRequestError, /unsupported mimetype/)
      end

      it 'rejects edits with a URL that returns 404' do
        expect do
          RubyLLM.paint(prompt, with: 'https://rubyllm.com/some-asset-that-does-not-exist.png', model: model)
        end.to raise_error(Faraday::ResourceNotFound)
      end
    end
  end
end
