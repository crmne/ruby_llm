# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Videos do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.vertexai_project_id = 'test-project'
    config.vertexai_location = 'us-central1'
    RubyLLM::Providers::VertexAI.new(config).tap do |instance|
      allow(instance).to receive(:connection).and_return(instance_double(RubyLLM::Transport::Connection))
    end
  end
  let(:model) { 'veo-3.1-fast-generate-001' }
  let(:protocol) { RubyLLM::Providers::VertexAI::Gemini.new(provider, model) }
  let(:operation_name) { "#{model_path}/operations/abc123" }

  def model_path
    "projects/test-project/locations/us-central1/publishers/google/models/#{model}"
  end

  describe '#animate_later' do
    it 'submits a non-idempotent prediction to the Vertex model endpoint' do
      response = instance_double(Faraday::Response, body: { 'name' => operation_name })
      allow(provider.connection).to receive(:post).and_return(response)

      result = protocol.animate_later(
        'a hummingbird in slow motion', model:,
                                        provider_options: { parameters: { durationSeconds: 4, sampleCount: 1 } }
      )

      expect(provider.connection).to have_received(:post).with(
        "#{model_path}:predictLongRunning",
        { instances: [{ prompt: 'a hummingbird in slow motion' }],
          parameters: { durationSeconds: 4, sampleCount: 1 } },
        idempotent: false
      )
      expect(result.id).to eq(operation_name)
      expect(result).to be_pending
    end

    it 'encodes reference images with the Vertex prediction fields' do
      path = File.expand_path('../../../fixtures/ruby.png', __dir__)
      payload = protocol.render_video_payload('animate the logo', model:, with: RubyLLM::Attachment.wrap(path))

      expect(payload[:instances].first[:image]).to eq(
        bytesBase64Encoded: Base64.strict_encode64(File.binread(path)), mimeType: 'image/png'
      )
    end
  end

  describe '#refresh_video_job' do
    let(:job) { RubyLLM::VideoJob.new(id: operation_name, protocol:, model:) }

    it 'polls with the operation name in a POST body and stays pending' do
      body = { 'name' => operation_name, 'done' => false }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))

      expect(job.refresh).to be_pending
      expect(provider.connection).to have_received(:post).with(
        "#{model_path}:fetchPredictOperation", { operationName: operation_name }
      )
    end

    it 'completes and decodes video bytes from the prediction response' do
      body = {
        'done' => true,
        'response' => { 'videos' => [{ 'bytesBase64Encoded' => Base64.strict_encode64('mp4 bytes'),
                                       'mimeType' => 'video/mp4' }] }
      }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))

      expect(job.refresh).to be_completed
      video = job.video
      expect(video.data).to eq('mp4 bytes')
      expect(video.mime_type).to eq('video/mp4')
      expect(video.model).to eq(model)
      expect(video.raw).to eq(body)
      expect(job.video).to equal(video)
    end

    it 'downloads Cloud Storage output through the provider file integration' do
      uri = 'gs://video-bucket/output/sample_0.mp4'
      body = { 'done' => true, 'response' => { 'videos' => [{ 'gcsUri' => uri, 'mimeType' => 'video/mp4' }] } }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))
      allow(provider).to receive(:download_file).with(uri).and_return('mp4 bytes')

      expect(job.refresh.video.data).to eq('mp4 bytes')
      expect(provider).to have_received(:download_file).with(uri).once
    end

    it 'surfaces prediction errors from both wait and video' do
      body = { 'done' => true, 'error' => { 'code' => 3, 'message' => 'Unsupported duration' } }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))

      expect { job.wait(timeout: 10, interval: 0) }.to raise_error(RubyLLM::Error, /Unsupported duration/)
      expect(job).to be_failed
      expect { job.video }.to raise_error(RubyLLM::Error, /Unsupported duration/)
    end

    it 'surfaces safety filtering when no video was generated' do
      body = { 'done' => true, 'response' => { 'raiMediaFilteredCount' => 1,
                                               'raiMediaFilteredReasons' => ['The prompt was blocked.'] } }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))

      expect(job.refresh).to be_failed
      expect(job.error).to eq('The prompt was blocked.')
    end

    it 'fails instead of completing when a finished response has no usable video' do
      body = { 'done' => true, 'response' => { 'videos' => [{ 'mimeType' => 'video/mp4' }] } }
      allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body:))

      expect(job.refresh).to be_failed
      expect(job.error).to eq('Vertex AI returned no video')
    end
  end

  describe '#render_video_extension_payload' do
    it 'extends Cloud Storage videos with the Vertex prediction format' do
      payload = protocol.render_video_extension_payload('Continue the scene', model:,
                                                                              extend: 'gs://video-bucket/source.mp4')

      expect(payload).to eq(instances: [{ prompt: 'Continue the scene',
                                          video: { gcsUri: 'gs://video-bucket/source.mp4', mimeType: 'video/mp4' } }])
    end

    it 'encodes Video bytes using Vertex fields instead of Gemini fields' do
      source = RubyLLM::Video.new(data: 'mp4 bytes', mime_type: 'video/mp4')
      payload = protocol.render_video_extension_payload('Continue', model:, extend: source)

      expect(payload[:instances].first[:video]).to eq(bytesBase64Encoded: 'bXA0IGJ5dGVz', mimeType: 'video/mp4')
    end
  end

  it 'extends a Cloud Storage video through a Vertex prediction job', :live do
    context = RubyLLM.context do |config|
      config.vertexai_location = 'us-central1'
      config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
    end
    job = context.animate_later(
      'A butterfly flies in and lands on the flower',
      model: model_for(:vertexai, :vertexai_video), provider: :vertexai, assume_model_exists: true,
      extend: 'gs://cloud-samples-data/generative-ai/video/flower.mp4',
      provider_options: { parameters: { sampleCount: 1, generateAudio: false } }
    )

    expect(job.wait(timeout: 240)).to be_completed
    expect(job.video.mime_type).to eq('video/mp4')
    expect(job.video.to_blob.bytesize).to be > 1000
  end

  it 'generates a video through a Vertex prediction job', :live do
    context = RubyLLM.context do |config|
      config.vertexai_location = 'us-central1'
      config.video_generation_poll_interval = VCR.current_cassette&.recording? ? 5 : 0
    end
    job = context.animate_later(
      'A calm ocean wave at sunset',
      model: model_for(:vertexai, :vertexai_video), provider: :vertexai, assume_model_exists: true,
      provider_options: { parameters: { durationSeconds: 4, sampleCount: 1, generateAudio: false } }
    )

    expect(job.id).to include('/operations/')
    expect(job.wait).to be_completed
    expect(job.video.mime_type).to eq('video/mp4')
    expect(job.video.to_blob.bytesize).to be > 10_000
  end
end
