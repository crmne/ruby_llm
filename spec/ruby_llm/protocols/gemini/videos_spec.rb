# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.gemini_api_key = 'test'
    RubyLLM::Providers::Gemini.new(config)
  end
  let(:protocol) { RubyLLM::Protocols::Gemini.new(provider, 'veo-3.1-fast-generate-preview') }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  describe '#render_video_payload' do
    it 'wraps the prompt in a predict instance and nests options through provider_options' do
      payload = protocol.render_video_payload(
        'a hummingbird in slow motion',
        model: 'veo-3.1-fast-generate-preview',
        provider_options: { parameters: { durationSeconds: 4, resolution: '720p' } }
      )

      expect(protocol.video_url).to eq('models/veo-3.1-fast-generate-preview:predictLongRunning')
      expect(payload).to eq(
        instances: [{ prompt: 'a hummingbird in slow motion' }],
        parameters: { durationSeconds: 4, resolution: '720p' }
      )
    end

    it 'inlines a reference image for image-to-video' do
      payload = protocol.render_video_payload(
        'bring the logo to life',
        model: 'veo-3.1-fast-generate-preview',
        with: RubyLLM::Attachment.wrap(image_path)
      )

      image = payload[:instances].first[:image][:inlineData]
      expect(image[:mimeType]).to eq('image/png')
      expect(Base64.decode64(image[:data])).to eq(File.binread(image_path))
    end
  end

  describe '#parse_video_job' do
    it 'reads the long-running operation name as the job id' do
      response = instance_double(
        Faraday::Response,
        body: { 'name' => 'models/veo-3.1-fast-generate-preview/operations/abc123' }
      )

      job = protocol.parse_video_job(response, model: 'veo-3.1-fast-generate-preview')

      expect(job.id).to eq('models/veo-3.1-fast-generate-preview/operations/abc123')
      expect(job).to be_pending
      expect(protocol.video_job_url(job)).to eq(job.id)
    end
  end

  describe '#parse_video_job_status' do
    let(:job) { RubyLLM::VideoJob.new(id: 'models/veo/operations/abc123', protocol: protocol) }

    it 'stays pending until the operation is done' do
      response = instance_double(Faraday::Response, body: { 'name' => 'models/veo/operations/abc123' })

      expect(protocol.parse_video_job_status(response, job: job)).to eq(
        status: :pending, raw: { 'name' => 'models/veo/operations/abc123' }
      )
    end

    it 'completes when the operation carries a generated video' do
      body = {
        'name' => 'models/veo/operations/abc123',
        'done' => true,
        'response' => {
          'generateVideoResponse' => {
            'generatedSamples' => [
              { 'video' => { 'uri' => 'https://generativelanguage.googleapis.com/v1beta/files/xyz:download?alt=media' } }
            ]
          }
        }
      }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to eq(status: :completed, raw: body)
    end

    it 'fails with the operation error message' do
      body = { 'done' => true, 'error' => { 'code' => 400, 'message' => 'unsupported duration' } }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to include(
        status: :failed, error: 'unsupported duration'
      )
    end

    it 'fails with the filter reasons when every sample was withheld' do
      body = {
        'done' => true,
        'response' => {
          'generateVideoResponse' => {
            'raiMediaFilteredCount' => 1,
            'raiMediaFilteredReasons' => ['Responsible AI practices blocked this prompt.']
          }
        }
      }
      response = instance_double(Faraday::Response, body: body)

      expect(protocol.parse_video_job_status(response, job: job)).to include(
        status: :failed, error: 'Responsible AI practices blocked this prompt.'
      )
    end
  end

  describe '#download_video' do
    let(:job) do
      raw = {
        'done' => true,
        'response' => {
          'generateVideoResponse' => {
            'generatedSamples' => [
              { 'video' => { 'uri' => 'https://generativelanguage.googleapis.com/v1beta/files/xyz:download?alt=media' } }
            ]
          }
        }
      }
      RubyLLM::VideoJob.new(id: 'models/veo/operations/abc123', protocol: protocol,
                            model: 'veo-3.1-fast-generate-preview', status: :completed, raw: raw)
    end

    it 'downloads the file URI through the authenticated connection' do
      response = instance_double(Faraday::Response, status: 200, headers: {}, body: 'mp4 bytes')
      allow(provider.connection).to receive(:get)
        .with('https://generativelanguage.googleapis.com/v1beta/files/xyz:download?alt=media')
        .and_return(response)

      video = protocol.download_video(job)

      expect(video.data).to eq('mp4 bytes')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.model).to eq('veo-3.1-fast-generate-preview')
    end

    it 'follows the redirect to the download host with the API key' do
      redirect = instance_double(
        Faraday::Response,
        status: 302,
        headers: { 'location' => 'https://generativelanguage.googleapis.com/download/v1beta/files/xyz:download' }
      )
      response = instance_double(Faraday::Response, status: 200, headers: {}, body: 'mp4 bytes')
      allow(provider.connection).to receive(:get)
        .with('https://generativelanguage.googleapis.com/v1beta/files/xyz:download?alt=media')
        .and_return(redirect)
      allow(provider.connection).to receive(:get)
        .with('https://generativelanguage.googleapis.com/download/v1beta/files/xyz:download')
        .and_return(response)

      expect(protocol.download_video(job).data).to eq('mp4 bytes')
    end
  end
end
