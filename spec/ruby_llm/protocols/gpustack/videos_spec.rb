# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::GPUStack::Videos do
  let(:model) { model_for(:gpustack) }
  let(:base) { 'https://gpu.example.test/cluster/model/proxy/42/v1/videos' }
  let(:context) do
    RubyLLM.context do |config|
      config.gpustack_api_base = 'https://gpu.example.test/cluster/model/proxy/42/v1/'
      config.gpustack_api_key = 'isolated-key'
      config.video_generation_poll_interval = 0
    end
  end
  let(:protocol) { RubyLLM::Providers::GPUStack::ChatCompletions.new(context.chat(model:, provider: :gpustack).provider) }
  let(:image) { RubyLLM::Attachment.new(StringIO.new('image'), filename: 'scene.png') }

  def audio
    RubyLLM::Attachment.new(StringIO.new('audio'), filename: 'voice.wav')
  end

  def state(status, **fields)
    { id: 'video_gen_1', model:, status:, seconds: '4', media_type: 'video/mp4' }.merge(fields)
  end

  it 'submits text-only multipart once, polls all states, and downloads bytes with proxy authentication' do
    request = stub_request(:post, base).with do |req|
      req.headers['Content-Type'].start_with?('multipart/form-data; boundary=') &&
        req.headers['Authorization'] == 'Bearer isolated-key' && req.body.include?('A rainy street') &&
        req.body.include?('name="model"') && req.body.include?(model)
    end.to_return_json(body: state('queued'))
    poll = stub_request(:get, "#{base}/video_gen_1")
           .to_return_json(body: state('in_progress')).then.to_return_json(body: state('completed'))
    download = stub_request(:get, "#{base}/video_gen_1/content")
               .with(headers: { 'Authorization' => 'Bearer isolated-key' })
               .to_return(body: "mp4\x00bytes".b, headers: { 'Content-Type' => 'video/mp4' })

    result = context.animate('A rainy street', model:, provider: :gpustack)

    expect(result).to have_attributes(data: "mp4\x00bytes".b, mime_type: 'video/mp4', duration: nil, model:)
    expect(result.raw['status']).to eq('completed')
    expect(result.to_blob).to eq("mp4\x00bytes".b)
    expect(request).to have_been_requested.once
    expect(poll).to have_been_requested.twice
    expect(download).to have_been_requested.once
  end

  it 'serializes image and audio input and nested backend options as JSON multipart fields' do
    payload = protocol.render_video_payload('A person singing', model:, with: [image, audio],
                                                                provider_options: { extra_params: { foo: 1 } })

    expect(JSON.parse(payload[:image_reference])).to eq('image_url' => 'data:image/png;base64,aW1hZ2U=')
    expect(JSON.parse(payload[:audio_reference])).to eq('audio_url' => 'data:audio/wav;base64,YXVkaW8=')
    expect(payload[:extra_params]).to eq('{"foo":1}')
  end

  it 'preserves ordered multiple references and passes remote videos without downloading them' do
    attachments = RubyLLM::Attachment.wrap(['https://media.test/first.png', 'https://media.test/last.png',
                                            'https://media.test/clip.mp4'])
    payload = protocol.render_video_payload('Continue the scene', model:, with: attachments)

    expect(JSON.parse(payload[:image_reference])).to eq([{ 'image_url' => 'https://media.test/first.png' },
                                                         { 'image_url' => 'https://media.test/last.png' }])
    expect(JSON.parse(payload[:video_reference])).to eq('video_url' => 'https://media.test/clip.mp4')
  end

  it 'accepts a local video through the public attachment API and sends a JSON reference field' do
    video = RubyLLM::Attachment.new(StringIO.new('video'), filename: 'scene.mp4')
    request = stub_request(:post, base).with do |req|
      req.body.include?('name="video_reference"') &&
        req.body.include?('{"video_url":"data:video/mp4;base64,dmlkZW8="}')
    end.to_return_json(body: state('queued'))

    job = context.animate_later('Change the light to sunset', model:, provider: :gpustack, with: video)

    expect(job).to be_pending
    expect(request).to have_been_requested.once
  end

  it 'preserves provider failure and rejects unknown job states rather than polling forever' do
    stub_request(:post,
                 base).to_return_json(body: state('failed', error: { code: 'render_error', message: 'Out of memory' }))
    job = context.animate_later('A street', model:, provider: :gpustack)

    expect(job).to be_failed
    expect(job.error).to eq('Out of memory')
    expect { job.video }.to raise_error(RubyLLM::Error, /Out of memory/)
    stub_request(:post, base).to_return_json(body: state('unrecognized'))
    expect { context.animate_later('A street', model:, provider: :gpustack) }
      .to raise_error(RubyLLM::Error, /Unknown GPUStack video status/)
  end

  it 'does not repeat a video submission after an uncertain transport failure' do
    context.config.max_retries = 3
    request = stub_request(:post, base).to_raise(Faraday::TimeoutError)

    expect { context.animate_later('A street', model:, provider: :gpustack) }.to raise_error(Faraday::TimeoutError)
    expect(request).to have_been_requested.once
  end

  it 'rejects unsupported gateway routes, references, multi-output requests, and extension before HTTP' do
    file = RubyLLM::UploadedFile.new(id: 'file_1', provider: :gpustack, filename: 'scene.png', mime_type: 'image/png')
    expect { context.animate_later('A street', model:, provider: :gpustack, with: file) }
      .to raise_error(ArgumentError, /uploaded file ids/)
    expect do
      context.animate_later('A street', model:, provider: :gpustack, provider_options: { num_outputs_per_prompt: 2 })
    end
      .to raise_error(ArgumentError, /one video/)
    expect { context.animate_later(model:, provider: :gpustack) }.to raise_error(ArgumentError, /requires a prompt/)
    expect { context.animate_later('Continue', model:, provider: :gpustack, extend: 'https://media.test/clip.mp4') }
      .to raise_error(RubyLLM::Error, /doesn't support video extension/)
    context.config.gpustack_api_base = 'https://gpu.example.test/v1'
    expect { context.animate_later('A street', model:, provider: :gpustack) }
      .to raise_error(RubyLLM::Error, %r{/model/proxy/ROUTE_ID/v1})
    expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
  end
end
