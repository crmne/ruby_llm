# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Video do
  before do
    RubyLLM.config.xai_api_key = 'test'
    RubyLLM.config.anthropic_api_key = 'test'
  end

  it 'returns a completed video through the blocking public API' do
    source = described_class.new(data: 'mp4 bytes', mime_type: 'video/mp4')
    request = stub_request(:post, 'https://api.x.ai/v1/videos/extensions')
              .with(body: hash_including('video' => { 'url' => 'data:video/mp4;base64,bXA0IGJ5dGVz' }))
              .to_return_json(body: { request_id: 'video_job' })
    stub_request(:get, 'https://api.x.ai/v1/videos/video_job')
      .to_return_json(body: { status: 'done', video: { url: 'https://example.com/extended.mp4', duration: 7 } })
    context = RubyLLM.context { |config| config.video_generation_poll_interval = 0 }

    result = context.animate('Continue', model: model_for(:xai, :video_extension), provider: :xai, extend: source)

    expect(request).to have_been_requested.once
    expect(result).to be_a(described_class)
    expect(result).to have_attributes(url: 'https://example.com/extended.mp4', duration: 7)
    expect(result.config).to equal(context.config)
  end

  it 'rejects extension on unsupported providers before issuing a request' do
    expect do
      RubyLLM.animate_later('Continue', model: model_for(:anthropic), provider: :anthropic,
                                        extend: 'https://example.com/clip.mp4')
    end.to raise_error(RubyLLM::Error, /Anthropic doesn't support video extension/)
  end
end
