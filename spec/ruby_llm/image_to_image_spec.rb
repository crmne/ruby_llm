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
    it 'gemini/gemini-2.0-flash-preview-image-generation can paint images' do
      chat = RubyLLM.chat(model: 'gemini-2.0-flash-preview-image-generation')
      response = chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png')

      expect(response.content.text).to include('ruby')

      expect(response.content.attachments).to be_an(Array)
      expect(response.content.attachments).not_to be_empty

      image = response.content.attachments.first.image

      expect(image.base64?).to be(true)
      expect(image.data).to be_present
      expect(image.mime_type).to include('image')

      save_and_verify_image image
    end

    it 'gemini/gemini-2.0-flash-preview-image-generation can refine images in a conversation' do
      chat = RubyLLM.chat(model: 'gemini-2.0-flash-preview-image-generation')
      chat.ask('put this in a ring', with: 'spec/fixtures/ruby.png')
      response = chat.ask('change the background to blue')

      expect(response.content.text).to include('ruby')

      expect(response.content.attachments).to be_an(Array)
      expect(response.content.attachments).not_to be_empty

      image = response.content.attachments.first.image

      expect(image.base64?).to be(true)
      expect(image.data).to be_present
      expect(image.mime_type).to include('image')

      save_and_verify_image image
    end
  end
end
