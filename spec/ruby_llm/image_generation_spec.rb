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
  end
end
