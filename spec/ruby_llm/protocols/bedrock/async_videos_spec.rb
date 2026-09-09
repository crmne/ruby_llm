# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Bedrock::AsyncVideos do
  let(:context) do
    RubyLLM.context do |config|
      config.bedrock_api_key = 'video-test-key'
      config.bedrock_secret_key = 'video-test-secret'
      config.bedrock_region = 'us-west-2'
      config.bedrock_video_s3_uri = 's3://test-bucket/intended-videos/'
      config.video_generation_poll_interval = 0
    end
  end
  let(:provider) { RubyLLM::Providers::Bedrock.new(context.config) }
  let(:protocol) { described_class.new(provider, RubyLLM.models.find(model, provider: :bedrock)) }
  let(:endpoint) { 'https://bedrock-runtime.us-west-2.amazonaws.com/async-invoke' }
  let(:job_id) { 'arn:aws:bedrock:us-west-2:123456789012:async-invoke/test-video' }

  before do |example|
    next if example.metadata[:live]

    allow(RubyLLM::Providers::Bedrock).to receive(:new).with(context.config).and_return(provider)
  end

  it 'generates and downloads a real Luma video under the intended S3 prefix', :live do
    uri = ENV.fetch('BEDROCK_VIDEO_S3_URI', nil)
    interaction = VCR.current_cassette.http_interactions.interactions
                     .find { |recorded| recorded.request.uri.end_with?('/async-invoke') }
    if interaction
      uri = JSON.parse(interaction.request.body).dig('outputDataConfig', 's3OutputDataConfig', 's3Uri')
    elsif VCR.current_cassette.recording?
      skip 'Set BEDROCK_VIDEO_S3_URI to an explicitly intended S3 output prefix' unless uri
    else
      skip 'No recorded Luma video; recording requires an explicitly intended BEDROCK_VIDEO_S3_URI'
    end
    live_context = RubyLLM.context { |config| config.bedrock_video_s3_uri = uri }
    job = live_context.animate_later('A paper boat floats on a still pond', model:, provider: :bedrock,
                                                                            provider_options: {
                                                                              duration: '5s', resolution: '540p'
                                                                            })
    expect(job.id).to include(':async-invoke/')
    video = job.wait(timeout: 300, interval: 2).video
    expect(video.mime_type).to eq('video/mp4')
    expect(video.to_blob.bytesize).to be > 1000
    expect(video.to_blob.byteslice(4, 4)).to eq('ftyp')
  end

  def model
    model_for(:bedrock, :bedrock_video)
  end

  def status_url
    "#{endpoint}/#{URI.encode_www_form_component(job_id)}"
  end

  def image
    RubyLLM::Attachment.new(StringIO.new('first-frame'), filename: 'first.png')
  end

  def state(status, **extra)
    { invocationArn: job_id, status:,
      outputDataConfig: {
        s3OutputDataConfig: { s3Uri: 's3://test-bucket/intended-videos/provider-job' }
      } }.merge(extra)
  end

  it 'signs one submission, polls its ARN, and downloads the single MP4 under the returned output prefix' do
    request = stub_request(:post, endpoint).with do |req|
      payload = JSON.parse(req.body)
      expect(payload).to include('modelId' => model,
                                 'modelInput' => { 'prompt' => 'A boat on a calm lake', 'duration' => '5s' },
                                 'outputDataConfig' => {
                                   's3OutputDataConfig' => { 's3Uri' => 's3://test-bucket/intended-videos/' }
                                 })
      expect(payload['clientRequestToken']).to match(/\A[\h-]{36}\z/)
      expect(req.headers['Authorization']).to include('/us-west-2/bedrock/aws4_request')
      expect(req.headers['X-Amz-Content-Sha256']).to eq(Digest::SHA256.hexdigest(req.body))
    end.to_return_json(body: { invocationArn: job_id })
    poll = stub_request(:get, status_url)
           .with { |req| req.headers['Authorization'].include?('/us-west-2/bedrock/aws4_request') }
           .to_return_json(body: state('InProgress')).then.to_return_json(body: state('Completed'))
    output = 's3://test-bucket/intended-videos/provider-job/actual-output.mp4'
    allow(provider).to receive_messages(list_file_uris: [output, output.sub('.mp4', '.json')],
                                        download_file: "mp4\x00bytes".b)

    video = context.animate('A boat on a calm lake', model:, provider: :bedrock, provider_options: { duration: '5s' })

    expect(video).to have_attributes(data: "mp4\x00bytes".b, mime_type: 'video/mp4', model:, duration: nil)
    expect(video.raw).to eq(JSON.parse(JSON.generate(state('Completed'))))
    expect(video.to_blob).to eq("mp4\x00bytes".b)
    expect(provider).to have_received(:list_file_uris).with('s3://test-bucket/intended-videos/provider-job/').once
    expect(provider).to have_received(:download_file).with(output).once
    expect(request).to have_been_requested.once
    expect(poll).to have_been_requested.twice
  end

  it 'renders first and last frames in the model input and keeps request options outside it' do
    last = RubyLLM::Attachment.new(StringIO.new('last-frame'), filename: 'last.jpg')
    request = stub_request(:post, endpoint).with do |req|
      payload = JSON.parse(req.body)
      expect(payload).to include('clientRequestToken' => 'request-123',
                                 'tags' => [{ 'key' => 'test', 'value' => 'video' }])
      expect(payload['modelInput']).to eq(
        'prompt' => 'A boat turns', 'aspect_ratio' => '16:9',
        'keyframes' => {
          'frame0' => { 'type' => 'image', 'source' => { 'type' => 'base64', 'media_type' => 'image/png',
                                                         'data' => Base64.strict_encode64('first-frame') } },
          'frame1' => { 'type' => 'image', 'source' => { 'type' => 'base64', 'media_type' => 'image/jpeg',
                                                         'data' => Base64.strict_encode64('last-frame') } }
        }
      )
    end.to_return_json(body: { invocationArn: job_id })

    job = context.animate_later('A boat turns', model:, provider: :bedrock, with: [image, last],
                                                provider_options: {
                                                  aspect_ratio: '16:9', clientRequestToken: 'request-123',
                                                  tags: [{ key: 'test', value: 'video' }]
                                                })
    expect(job).to have_attributes(id: job_id, status: :pending, model:)
    expect(request).to have_been_requested.once
  end

  it 'retains failed job metadata and rejects unknown or absent job states' do
    stub_request(:post, endpoint).to_return_json(body: { invocationArn: job_id })
    stub_request(:get,
                 status_url).to_return_json(body: state('Failed', failureMessage: 'The model rejected the prompt'))
    job = context.animate_later('A boat', model:, provider: :bedrock).refresh
    expect(job).to be_failed
    expect(job.raw['failureMessage']).to eq('The model rejected the prompt')
    expect { job.video }.to raise_error(RubyLLM::Error, /The model rejected the prompt/)

    stub_request(:get, status_url).to_return_json(body: state('NewState'))
    expect { context.animate_later('A boat', model:, provider: :bedrock).refresh }
      .to raise_error(RubyLLM::Error, /Unknown Bedrock video status/)
    stub_request(:post, endpoint).to_return_json(body: {})
    expect { context.animate_later('A boat', model:, provider: :bedrock) }
      .to raise_error(RubyLLM::Error, /invocation ARN/)
  end

  it 'does not repeat an uncertain submission despite configured retries' do
    context.config.max_retries = 3
    request = stub_request(:post, endpoint).to_raise(Faraday::TimeoutError)

    expect { context.animate_later('A boat', model:, provider: :bedrock) }.to raise_error(Faraday::TimeoutError)
    expect(request).to have_been_requested.once
  end

  it 'requires an explicit output prefix without falling back to the batch destination' do
    context.config.bedrock_batch_s3_uri = 's3://other-bucket/batches'
    [nil, 's3://bucket', 'https://bucket.test/videos', 's3://bucket/'].each do |uri|
      context.config.bedrock_video_s3_uri = uri
      expect { context.animate_later('A boat', model:, provider: :bedrock) }
        .to raise_error(RubyLLM::ConfigurationError, /bedrock_video_s3_uri/)
    end
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'rejects unsupported models, prompts, attachments, and extensions before HTTP' do
    expect { context.animate_later('A boat', model: model_for(:bedrock), provider: :bedrock) }
      .to raise_error(RubyLLM::Error, /video generation is not supported/)
    [nil, '', 'x' * 5001].each do |prompt|
      expect do
        context.animate_later(prompt, model:, provider: :bedrock)
      end.to raise_error(ArgumentError, /requires a prompt/)
    end
    expect { context.animate_later('A boat', model:, provider: :bedrock, with: [image, image, image]) }
      .to raise_error(ArgumentError, /at most two reference images/)
    expect { context.animate_later('A boat', model:, provider: :bedrock, with: 'https://media.test/boat.mp4') }
      .to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect { context.animate_later('Continue', model:, provider: :bedrock, extend: 'https://media.test/boat.mp4') }
      .to raise_error(RubyLLM::Error, /doesn't support video extension/)
    file = RubyLLM::UploadedFile.new(id: 's3://bucket/boat.png', mime_type: 'image/png')
    expect { context.animate_later('A boat', model:, provider: :bedrock, with: file) }
      .to raise_error(ArgumentError, /not uploaded file ids/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'refuses to guess an output object when metadata or the single MP4 is absent' do
    missing = RubyLLM::VideoJob.new(id: job_id, protocol:, model:, status: :completed, raw: {})
    allow(provider).to receive(:list_file_uris)
    expect { missing.video }.to raise_error(RubyLLM::Error, /no output S3 URI/)
    expect(provider).not_to have_received(:list_file_uris)
  end

  it 'refuses multiple output videos instead of downloading an arbitrary object' do
    job = RubyLLM::VideoJob.new(id: job_id, protocol:, model:, status: :completed,
                                raw: JSON.parse(JSON.generate(state('Completed'))))
    allow(provider).to receive(:list_file_uris).and_return([],
                                                           ['s3://test-bucket/videos/a.mp4',
                                                            's3://test-bucket/videos/b.mp4'])
    allow(provider).to receive(:download_file)
    2.times { expect { job.video }.to raise_error(RubyLLM::Error, /exactly one MP4/) }
    expect(provider).not_to have_received(:download_file)
  end
end
