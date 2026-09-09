# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.xai_api_key = 'test'
    RubyLLM::Providers::XAI.new(config)
  end
  let(:model) { model_for(:xai, :video_extension) }
  let(:protocol) { RubyLLM::Providers::XAI::Responses.new(provider, model) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  describe '#render_video_payload' do
    it 'sends model, prompt, and provider options' do
      payload = protocol.render_video_payload(
        'make the water crash down',
        model: 'grok-imagine-video',
        provider_options: { duration: 1, resolution: '480p' }
      )

      expect(protocol.video_url).to eq('videos/generations')
      expect(payload).to eq(
        model: 'grok-imagine-video',
        prompt: 'make the water crash down',
        duration: 1,
        resolution: '480p'
      )
    end

    it 'references a remote image by URL for image-to-video' do
      payload = protocol.render_video_payload(
        'make the water crash down',
        model: 'grok-imagine-video',
        with: RubyLLM::Attachment.wrap('https://example.com/waterfall.png')
      )

      expect(payload[:image]).to eq(url: 'https://example.com/waterfall.png')
    end

    it 'inlines a local image as a data URI' do
      payload = protocol.render_video_payload(
        'bring the logo to life',
        model: 'grok-imagine-video',
        with: RubyLLM::Attachment.wrap(image_path)
      )

      expect(payload[:image][:url]).to start_with('data:image/png;base64,')
    end
  end

  describe '#parse_video_job' do
    it 'reads the request id' do
      response = instance_double(Faraday::Response, body: { 'request_id' => '4482fadb-85bb-9591-9900-d3cc54d84fb8' })

      job = protocol.parse_video_job(response, model: 'grok-imagine-video')

      expect(job.id).to eq('4482fadb-85bb-9591-9900-d3cc54d84fb8')
      expect(job).to be_pending
      expect(protocol.video_job_url(job)).to eq('videos/4482fadb-85bb-9591-9900-d3cc54d84fb8')
    end
  end

  describe 'video editing and extension' do
    let(:video) { RubyLLM::Attachment.new(StringIO.new('mp4 bytes'), filename: 'clip.mp4') }

    it 'selects the editing route for local video attachments' do
      payload = protocol.render_video_payload('Turn the background blue', model:, with: [video])

      expect(payload[:video]).to eq(url: 'data:video/mp4;base64,bXA0IGJ5dGVz')
      expect(protocol.video_request_url(payload)).to eq('videos/edits')
      expect(protocol.video_request_url(model:, prompt: 'A blue bird')).to eq('videos/generations')
    end

    it 'references uploaded images and videos using file_id fields' do
      file = RubyLLM::UploadedFile.new(id: 'file_video', provider: :xai, filename: 'clip.mp4',
                                       mime_type: 'video/mp4')
      payload = protocol.render_video_payload('Turn the background blue', model:,
                                                                          with: RubyLLM::Attachment.wrap(file))

      expect(payload[:video]).to eq(file_id: 'file_video')
      expect(protocol.render_video_extension_payload('Continue', model:, extend: file)[:video])
        .to eq(file_id: 'file_video')
    end

    it 'extends typed Video results and preserves extension options' do
      source = RubyLLM::Video.new(url: 'https://example.com/clip.mp4', mime_type: 'video/mp4')
      payload = protocol.render_video_extension_payload('Continue the shot', model:, extend: source,
                                                                             provider_options: { duration: 2 })

      expect(payload).to eq(model: model, prompt: 'Continue the shot', duration: 2,
                            video: { url: 'https://example.com/clip.mp4' })
      expect(protocol.video_extension_url).to eq('videos/extensions')
    end

    it 'rejects conflicting sources and invalid extension inputs before sending requests' do
      expect { protocol.animate_later('Continue', model:, with: image_path, extend: video) }
        .to raise_error(ArgumentError, /cannot be combined/)
      expect { protocol.animate_later('Continue', model:, extend: [video, video]) }
        .to raise_error(ArgumentError, /exactly one video/)
      expect { protocol.animate_later('Continue', model:, extend: image_path) }
        .to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  %i[with extend].each do |source_option|
    it "completes a video #{source_option == :with ? 'edit' : 'extension'} through the public API", :live do
      context = RubyLLM.context do |config|
        config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
      end
      options = { source_option => 'https://data.x.ai/docs/video-generation/portrait-wave.mp4' }
      options[:provider_options] = { duration: 2 } if source_option == :extend
      prompt = source_option == :with ? 'Make the background blue' : 'Continue the gentle waving motion'

      job = context.animate_later(prompt, model:, provider: :xai, **options)

      expect(job.id).not_to be_empty
      expect(job.wait(timeout: 180)).to be_completed
      expect(job.video.mime_type).to eq('video/mp4')
      expect(job.video.to_blob.bytesize).to be > 1000
      expect(job.video.raw['status']).to eq('done')
    end
  end

  describe '#parse_video_job_status' do
    let(:job) { RubyLLM::VideoJob.new(id: '4482fadb', protocol: protocol) }

    it 'stays pending while the video renders' do
      response = instance_double(Faraday::Response, body: { 'status' => 'pending', 'progress' => 68 })

      expect(protocol.parse_video_job_status(response, job: job)).to eq(
        status: :pending, raw: { 'status' => 'pending', 'progress' => 68 }
      )
    end

    it 'completes on done and exposes the hosted video' do
      body = {
        'status' => 'done',
        'video' => { 'url' => 'https://vidgen.x.ai/xai-vidgen-bucket/xai-video-4482fadb.mp4', 'duration' => 1 },
        'model' => 'grok-imagine-video',
        'usage' => { 'cost_in_usd_ticks' => 500_000_000 },
        'progress' => 100
      }
      response = instance_double(Faraday::Response, body: body)

      state = protocol.parse_video_job_status(response, job: job)
      expect(state).to eq(status: :completed, raw: body)

      video = protocol.download_video(
        RubyLLM::VideoJob.new(id: '4482fadb', protocol: protocol, status: :completed, raw: body)
      )
      expect(video.url).to eq('https://vidgen.x.ai/xai-vidgen-bucket/xai-video-4482fadb.mp4')
      expect(video.duration).to eq(1)
      expect(video.model).to eq('grok-imagine-video')
      expect(video.mime_type).to eq('video/mp4')
    end

    it 'fails on failed and expired statuses' do
      response = instance_double(Faraday::Response, body: { 'status' => 'expired' })

      expect(protocol.parse_video_job_status(response, job: job)).to include(status: :failed, error: 'expired')
    end
  end
end
