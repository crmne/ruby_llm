# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Video, :live do
  include_context 'with configured RubyLLM'

  before do
    RubyLLM.config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
  end

  each_model(VIDEO_GENERATION_MODELS) do |provider, model, model_info|
    it "#{provider}/#{model} animates a video" do
      video = RubyLLM.animate(
        'a calm ocean wave at sunset',
        model: model,
        provider: provider,
        assume_model_exists: true,
        provider_options: model_info.fetch(:provider_options, {})
      )

      expect(video.mime_type).to include('video')
      expect(video.url || video.data).not_to be_nil
      expect(video.to_blob.bytesize).to be > 10_000
    end
  end
end
