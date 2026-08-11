# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.xai_api_key = 'test'
    RubyLLM::Providers::XAI.new(config)
  end
  let(:protocol) { RubyLLM::Providers::XAI::Responses.new(provider, 'grok-imagine-video') }
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
