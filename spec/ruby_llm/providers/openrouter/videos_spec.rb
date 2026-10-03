# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.openrouter_api_key = 'test'
    RubyLLM::Providers::OpenRouter.new(config)
  end
  let(:protocol) { RubyLLM::Providers::OpenRouter::ChatCompletions.new(provider, 'x-ai/grok-imagine-video') }

  describe '#render_video_payload' do
    it 'sends model, prompt, and provider options' do
      payload = protocol.render_video_payload(
        'a calm ocean wave at sunset',
        model: 'x-ai/grok-imagine-video',
        provider_options: { duration: 1, resolution: '480p' }
      )

      expect(protocol.video_url).to eq('videos')
      expect(payload).to eq(
        model: 'x-ai/grok-imagine-video',
        prompt: 'a calm ocean wave at sunset',
        duration: 1,
        resolution: '480p'
      )
    end

    it 'maps reference images to first and last frames' do
      payload = protocol.render_video_payload(
        'the camera slowly pushes in',
        model: 'google/veo-3.1-lite',
        with: RubyLLM::Attachment.wrap(['https://example.com/first.jpg', 'https://example.com/last.jpg'])
      )

      expect(payload[:frame_images]).to eq(
        [
          { type: 'image_url', image_url: { url: 'https://example.com/first.jpg' }, frame_type: 'first_frame' },
          { type: 'image_url', image_url: { url: 'https://example.com/last.jpg' }, frame_type: 'last_frame' }
        ]
      )
    end
  end

  describe '#parse_video_request' do
    it 'reads the requested duration and resolution, or the size in pixels' do
      payload = protocol.render_video_payload('a wave', model: 'x-ai/grok-imagine-video',
                                                        provider_options: { duration: 1, resolution: '480p' })
      sized = protocol.render_video_payload('a wave', model: 'x-ai/grok-imagine-video',
                                                      provider_options: { size: '1280x720' })

      expect(protocol.parse_video_request(payload)).to eq(duration: 1, resolution: '480p')
      expect(protocol.parse_video_request(sized)).to eq(duration: nil, resolution: '1280x720')
    end
  end

  describe '#parse_video_job' do
    it 'reads the job id and status from the accepted job' do
      response = instance_double(
        Faraday::Response,
        body: { 'id' => 'abc123', 'polling_url' => 'https://openrouter.ai/api/v1/videos/abc123',
                'status' => 'pending' }
      )

      job = protocol.parse_video_job(response, model: 'x-ai/grok-imagine-video')

      expect(job.id).to eq('abc123')
      expect(job).to be_pending
      expect(protocol.video_job_url(job)).to eq('videos/abc123')
    end
  end

  describe '#parse_video_job_status' do
    let(:job) { RubyLLM::VideoJob.new(id: 'abc123', protocol: protocol) }

    it 'stays pending while the job is in progress' do
      response = instance_double(Faraday::Response, body: { 'id' => 'abc123', 'status' => 'in_progress' })

      expect(protocol.parse_video_job_status(response, job: job)).to eq(
        status: :pending, raw: { 'id' => 'abc123', 'status' => 'in_progress' }
      )
    end

    it 'completes when the job reports completed' do
      body = {
        'id' => 'abc123',
        'status' => 'completed',
        'unsigned_urls' => ['https://openrouter.ai/api/v1/videos/abc123/content?index=0'],
        'usage' => { 'cost' => 0.05 }
      }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to eq(status: :completed, raw: body,
                                                                        reported_cost: 0.05)
    end

    it 'reports the cost OpenRouter billed as the job and usage cost' do
      body = { 'id' => 'abc123', 'generation_id' => 'gen-1234567890-abcdef', 'status' => 'completed',
               'unsigned_urls' => ['https://openrouter.ai/api/v1/videos/abc123/content?index=0'],
               'usage' => { 'cost' => 0.25, 'is_byok' => false } }
      allow(provider.connection).to receive(:get).with('videos/abc123')
                                                 .and_return(instance_double(Faraday::Response, body:))
      allow(RubyLLM::Accounting::Usage).to receive(:report)

      job.refresh

      expect(job.cost.total).to eq(0.25)
      expect(RubyLLM::Accounting::Usage).to have_received(:report)
        .with(having_attributes(operation: :video, cost: having_attributes(total: 0.25)), config: anything)
    end

    it 'fails with the reported error' do
      response = instance_double(Faraday::Response, body: { 'status' => 'failed', 'error' => 'provider rejected' })

      expect(protocol.parse_video_job_status(response, job: job)).to include(
        status: :failed, error: 'provider rejected'
      )
    end
  end

  describe '#download_video' do
    it 'downloads the job content with the API connection' do
      job = RubyLLM::VideoJob.new(id: 'abc123', protocol: protocol, model: 'x-ai/grok-imagine-video',
                                  status: :completed, raw: { 'status' => 'completed' })
      response = instance_double(Faraday::Response, body: 'mp4 bytes', headers: { 'content-type' => 'video/mp4' })
      allow(provider.connection).to receive(:get).with('videos/abc123/content?index=0').and_return(response)

      video = protocol.download_video(job)

      expect(video.data).to eq('mp4 bytes')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.model).to eq('x-ai/grok-imagine-video')
    end
  end
end
