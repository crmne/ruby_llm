# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ElevenLabs::Flows do
  let(:context) do
    RubyLLM.context do |config|
      config.elevenlabs_api_key = 'test'
      config.video_generation_poll_interval = 0
    end
  end
  let(:model) { model_for(:elevenlabs, :elevenlabs_image) }
  let(:video_model) { model_for(:elevenlabs, :elevenlabs_video) }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }
  let(:protocol) { described_class.new(RubyLLM::Providers::ElevenLabs.new(context.config), model) }

  def image_url
    'https://media.example.test/output.png?signature=public-test'
  end

  def completed_image
    { id: 'generation_image', status: 'completed', content_url: image_url, content_mime_type: 'image/png' }
  end

  it 'generates and edits images through the public API with typed output and safe download headers' do
    requests = stub_request(:post, 'https://api.elevenlabs.io/v1/flows/image')
               .with { |request| JSON.parse(request.body)['model_id'] == model }
               .to_return_json(body: { id: 'generation_image', status: 'pending' })
    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/image/generation_image')
      .to_return_json(body: completed_image)
    download = stub_request(:get, image_url).with { |request| !request.headers.key?('Xi-Api-Key') }
                                            .to_return(body: 'PNG bytes')

    original = context.paint('A ruby on a white background', model:, provider: :elevenlabs, assume_model_exists: true)
    edited = context.paint('Turn the ruby blue', model:, provider: :elevenlabs, assume_model_exists: true,
                                                 with: image_path, size: '1024x1024')

    expect(original).to be_a(RubyLLM::Image)
    expect(edited).to have_attributes(model:, mime_type: 'image/png')
    expect(edited.to_blob).to eq('PNG bytes')
    expect(edited.tokens.to_h).to be_empty
    expect(requests).to have_been_requested.twice
    expect(download).to have_been_requested.once
    expect(a_request(:post, 'https://api.elevenlabs.io/v1/flows/image').with do |request|
      body = JSON.parse(request.body)
      body['aspect_ratio'] == '1:1' && body.dig('images', 0, 'type') == 'inline_base64'
    end).to have_been_made.once
  end

  it 'polls pending image jobs and reports failures and missing output URLs' do
    allow(protocol).to receive(:sleep)
    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/image/pending')
      .to_return_json(body: { status: 'generating' }).then.to_return_json(body: completed_image)
    expect(protocol.wait_for_image('pending')).to include('content_url' => image_url)

    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/image/failed')
      .to_return_json(body: { status: 'failed', failure_reason: 'moderated', error_message: 'Image was moderated' })
    expect { protocol.wait_for_image('failed') }.to raise_error(RubyLLM::Error, /Image was moderated/)
    expect { protocol.parse_generation_status('status' => 'completed') }
      .to raise_error(RubyLLM::Error, /without an output URL/)
  end

  it 'bounds image polling and includes the generation ID when it times out' do
    context.config.request_timeout = 0
    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/image/queued').to_return_json(body: { status: 'pending' })

    expect { protocol.wait_for_image('queued') }.to raise_error(RubyLLM::Error, /timed out: queued/)
  end

  it 'does not submit another image job after an uncertain transport failure' do
    request = stub_request(:post, 'https://api.elevenlabs.io/v1/flows/image')
              .to_raise(Faraday::TimeoutError.new('response lost after submission'))

    expect do
      context.paint('A ruby', model:, provider: :elevenlabs, assume_model_exists: true)
    end.to raise_error(Faraday::TimeoutError)
    expect(request).to have_been_requested.once
  end

  it 'passes uploaded asset references and masks without converting IDs to URLs' do
    file = RubyLLM::UploadedFile.new(id: 'asset_image', provider: :elevenlabs, filename: 'image.png',
                                     mime_type: 'image/png')
    payload = protocol.render_image_payload('Change the background', model: 'gpt-image-2', size: nil,
                                                                     with: file, mask: RubyLLM::Attachment.new(image_path))

    expect(payload[:images]).to eq([{ type: 'asset', asset_id: 'asset_image' }])
    expect(payload[:mask]).to include(type: 'inline_base64', mime_type: 'image/png')
    expect do
      protocol.render_image_payload('Change it', model:, size: nil, with: file, mask: image_path)
    end.to raise_error(ArgumentError, /GPT Image model/)
  end

  it 'rejects references owned by another provider' do
    file = RubyLLM::UploadedFile.new(id: 'file_image', provider: :openai, filename: 'image.png', mime_type: 'image/png')

    expect { protocol.render_media_reference(RubyLLM::Attachment.new(file)) }
      .to raise_error(ArgumentError, /same provider/)
  end

  it 'collects a video job and passes first and last frame images through the public API' do
    request = stub_request(:post, 'https://api.elevenlabs.io/v1/flows/video').with do |req|
      body = JSON.parse(req.body)
      body['model_id'] == video_model && body.dig('start_frame', 'type') == 'inline_base64' &&
        body.dig('end_frame', 'type') == 'inline_base64'
    end.to_return_json(body: { id: 'generation_video', status: 'pending' })
    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/video/generation_video')
      .to_return_json(body: { status: 'generating' }).then.to_return_json(body: {
                                                                            id: 'generation_video', status: 'completed',
                                                                            content_url: 'https://media.example.test/output.mp4',
                                                                            content_mime_type: 'video/mp4'
                                                                          })

    job = context.animate_later('A ruby turns slowly', model: video_model, provider: :elevenlabs,
                                                       assume_model_exists: true, with: [image_path, image_path])

    expect(job.wait(timeout: 1)).to be_completed
    expect(job.video).to have_attributes(model: video_model, mime_type: 'video/mp4')
    expect(job.video.raw['id']).to eq('generation_video')
    expect(request).to have_been_requested.once
  end

  it 'maps documented Seedance reference video input and refuses it for Veo' do
    source = RubyLLM::UploadedFile.new(id: 'asset_video', provider: :elevenlabs, filename: 'scene.mp4',
                                       mime_type: 'video/mp4')
    attachments = RubyLLM::Attachment.wrap(source)
    payload = protocol.render_video_payload('Change the lighting', model: 'bytedance-seedance-v2', with: attachments)

    expect(payload[:videos]).to eq([{ type: 'asset', asset_id: 'asset_video' }])
    expect { protocol.render_video_payload('Change it', model: video_model, with: attachments) }
      .to raise_error(ArgumentError, /only accepts image attachments/)
  end

  it 'leaves speech and transcription on the existing audio protocol' do
    provider = RubyLLM::Providers::ElevenLabs.new(context.config)
    expect(provider.resolve_protocol(nil, nil, operation: :speak)).to eq(RubyLLM::Protocols::ElevenLabs)
    expect(provider.resolve_protocol(nil, nil, operation: :transcribe)).to eq(RubyLLM::Protocols::ElevenLabs)
  end

  it 'maps Aurora character animation to singular image and speech audio references' do
    audio = RubyLLM::UploadedFile.new(id: 'asset_audio', provider: :elevenlabs, filename: 'speech.wav',
                                      mime_type: 'audio/wav')
    request = stub_request(:post, 'https://api.elevenlabs.io/v1/flows/video').with do |req|
      body = JSON.parse(req.body)
      body['model_id'] == 'creatify-aurora' && body.dig('image', 'type') == 'inline_base64' &&
        body['audio'] == { 'type' => 'asset', 'asset_id' => 'asset_audio' } && !body.key?('prompt') &&
        body['audio_guidance_scale'] == 2
    end.to_return_json(body: { id: 'aurora_generation', status: 'pending' })
    stub_request(:get, 'https://api.elevenlabs.io/v1/flows/video/aurora_generation')
      .to_return_json(body: { id: 'aurora_generation', status: 'completed',
                              content_url: 'https://media.example.test/character.mp4', content_mime_type: 'video/mp4' })

    job = context.animate_later(model: 'creatify-aurora', provider: :elevenlabs, assume_model_exists: true,
                                with: [audio, image_path], provider_options: { audio_guidance_scale: 2 })

    expect(job).to have_attributes(id: 'aurora_generation', model: 'creatify-aurora')
    video = RubyLLM.animate(model: 'creatify-aurora', provider: :elevenlabs, assume_model_exists: true, context:,
                            with: [audio, image_path], provider_options: { audio_guidance_scale: 2 })
    expect(video).to have_attributes(model: 'creatify-aurora', mime_type: 'video/mp4')
    expect(request).to have_been_requested.twice
    expect do
      protocol.render_video_payload('Ignored directions', model: 'creatify-aurora',
                                                          with: RubyLLM::Attachment.wrap([image_path, audio]))
    end.to raise_error(ArgumentError, /omit the prompt/)
    expect do
      protocol.render_video_payload(nil, model: 'creatify-aurora', with: RubyLLM::Attachment.wrap(image_path))
    end.to raise_error(ArgumentError, /exactly one image and one audio/)
    expect { protocol.render_video_payload(nil, model: video_model) }
      .to raise_error(ArgumentError, /requires a prompt/)
  end

  it 'generates an image through ElevenLabs Image and Video', :live do
    image = RubyLLM.paint('A small red ruby on a plain white background', model:, provider: :elevenlabs,
                                                                          assume_model_exists: true)

    expect(image).to be_a(RubyLLM::Image)
    expect(image.mime_type).to start_with('image/')
    expect(image.to_blob.bytesize).to be > 1000
  rescue RubyLLM::Error => e
    skip "ElevenLabs Image & Video requires Pro: #{e.message}" if e.response&.status == 402
    raise
  end

  it 'generates a video through an ElevenLabs video job', :live do
    job = RubyLLM.animate_later('A paper boat drifting on still water', model: video_model, provider: :elevenlabs,
                                                                        assume_model_exists: true,
                                                                        provider_options: { duration_secs: 4,
                                                                                            generate_audio: false })

    expect(job.wait(timeout: 240)).to be_completed
    expect(job.video.mime_type).to eq('video/mp4')
    expect(job.video.to_blob.bytesize).to be > 1000
  rescue RubyLLM::Error => e
    skip "ElevenLabs Image & Video requires Pro: #{e.message}" if e.response&.status == 402
    raise
  end
end
