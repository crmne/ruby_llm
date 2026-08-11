# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.azure_api_base = 'https://contoso.services.ai.azure.com'
    config.azure_api_key = 'test'
    RubyLLM::Providers::Azure.new(config)
  end
  let(:protocol) { RubyLLM::Providers::Azure::ChatCompletions.new(provider, 'sora-2') }

  describe '#render_video_payload' do
    it 'targets the preview jobs endpoint under the openai/v1 base' do
      payload = protocol.render_video_payload(
        'a cat playing piano in a jazz bar',
        model: 'sora-2',
        provider_options: { width: 480, height: 480, n_seconds: 5 }
      )

      expect(protocol.video_url).to eq(
        'https://contoso.services.ai.azure.com/openai/v1/video/generations/jobs?api-version=preview'
      )
      expect(payload).to eq(
        model: 'sora-2',
        prompt: 'a cat playing piano in a jazz bar',
        width: 480,
        height: 480,
        n_seconds: 5
      )
    end
  end

  describe '#parse_video_job' do
    it 'reads the job id from the created job' do
      response = instance_double(
        Faraday::Response,
        body: {
          'object' => 'video.generation.job',
          'id' => 'task_01jwcet0eje35tc5jy54yjax5q',
          'status' => 'queued',
          'generations' => [],
          'n_seconds' => 5,
          'failure_reason' => nil
        }
      )

      job = protocol.parse_video_job(response, model: 'sora-2')

      expect(job.id).to eq('task_01jwcet0eje35tc5jy54yjax5q')
      expect(job).to be_pending
      expect(protocol.video_job_url(job)).to eq(
        'https://contoso.services.ai.azure.com/openai/v1/video/generations/jobs/' \
        'task_01jwcet0eje35tc5jy54yjax5q?api-version=preview'
      )
    end
  end

  describe '#parse_video_job_status' do
    let(:job) { RubyLLM::VideoJob.new(id: 'task_01', protocol: protocol) }

    it 'stays pending through the queued and processing states' do
      %w[queued preprocessing running processing].each do |status|
        response = instance_double(Faraday::Response, body: { 'status' => status })

        expect(protocol.parse_video_job_status(response, job: job)).to eq(
          status: :pending, raw: { 'status' => status }
        )
      end
    end

    it 'completes on succeeded' do
      body = { 'status' => 'succeeded', 'generations' => [{ 'id' => 'gen_01' }] }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to eq(status: :completed, raw: body)
    end

    it 'fails with the failure reason' do
      body = { 'status' => 'failed', 'failure_reason' => 'moderation_blocked' }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to include(
        status: :failed, error: 'moderation_blocked'
      )
    end
  end

  describe '#download_video' do
    it 'downloads the first generation content' do
      raw = { 'status' => 'succeeded', 'generations' => [{ 'id' => 'gen_01' }], 'model' => 'sora-2', 'n_seconds' => 5 }
      job = RubyLLM::VideoJob.new(id: 'task_01', protocol: protocol, status: :completed, raw: raw)
      response = instance_double(Faraday::Response, body: 'mp4 bytes', headers: { 'content-type' => 'video/mp4' })
      allow(provider.connection).to receive(:get)
        .with('https://contoso.services.ai.azure.com/openai/v1/video/generations/gen_01/content/video' \
              '?api-version=preview')
        .and_return(response)

      video = protocol.download_video(job)

      expect(video.data).to eq('mp4 bytes')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.duration).to eq(5)
    end

    it 'raises when the job carries no generations' do
      job = RubyLLM::VideoJob.new(id: 'task_01', protocol: protocol, status: :completed,
                                  raw: { 'status' => 'succeeded', 'generations' => [] })

      expect { protocol.download_video(job) }.to raise_error(RubyLLM::Error, /no generations/)
    end
  end
end
