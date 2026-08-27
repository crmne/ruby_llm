# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Image, :live do
  include_context 'with configured RubyLLM'

  each_model(IMAGE_GENERATION_MODELS) do |provider, model, model_info|
    it "#{provider}/#{model} paints an image" do
      image = RubyLLM.paint(
        'a siamese cat',
        model: model,
        provider: provider,
        assume_model_exists: true,
        provider_options: model_info.fetch(:provider_options, {})
      )

      expect(image.mime_type).to include('image')
      expect(image.model).to eq(model)
      expect(image.to_blob.bytesize).to be > 1000
    end
  end
end
