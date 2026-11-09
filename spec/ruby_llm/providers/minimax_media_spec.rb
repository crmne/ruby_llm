# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do
  subject(:provider) { described_class.new(config) }

  let(:config) { RubyLLM::Configuration.new.tap { |provider_config| provider_config.minimax_api_key = 'test-key' } }

  def context
    RubyLLM.context { |context_config| context_config.minimax_api_key = 'test-key' }
  end

  def stub_json(method, url, body)
    stub_request(method, url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body(url)
    body = nil
    expect(a_request(:post, url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  def fixture(name)
    File.expand_path("../../fixtures/#{name}", __dir__)
  end

  describe 'media endpoints' do
    it 'reaches them at the root of the configured host' do
      expect(provider.media_base).to eq('https://api.minimax.io')

      config.minimax_api_base = 'https://api.minimax.cn/anthropic/'

      expect(provider.media_base).to eq('https://api.minimax.cn')
    end
  end

  describe 'failures reported in a 200 body' do
    let(:url) { 'https://api.minimax.io/v1/t2a_v2' }

    def stub_failure(code, message)
      stub_json(:post, url, base_resp: { status_code: code, status_msg: message })
    end

    it 'raises the matching error with the message' do
      stub_failure(1008, 'insufficient balance')

      expect { context.speak('Hi', model: 'speech-2.8-turbo', provider: :minimax, assume_model_exists: true) }
        .to raise_error(RubyLLM::PaymentRequiredError, /insufficient balance/)
    end

    it 'treats an unknown code as a bad request' do
      stub_failure(2013, 'invalid params')

      expect { context.speak('Hi', model: 'speech-2.8-turbo', provider: :minimax, assume_model_exists: true) }
        .to raise_error(RubyLLM::BadRequestError, /invalid params/)
    end
  end

  describe 'images' do
    let(:url) { 'https://api.minimax.io/v1/image_generation' }

    before do
      stub_json(:post, url, data: { image_base64: [Base64.strict_encode64('jpeg')] },
                            base_resp: { status_code: 0, status_msg: 'success' })
    end

    it 'sends a size as width and height, and a ratio as an aspect ratio' do
      context.paint('A cat', model: 'image-01', provider: :minimax, assume_model_exists: true, size: '1024x768')
      expect(sent_body(url)).to include('width' => 1024, 'height' => 768, 'response_format' => 'base64')

      WebMock.reset_executed_requests!
      context.paint('A cat', model: 'image-01', provider: :minimax, assume_model_exists: true, size: '16:9')
      expect(sent_body(url)).to include('aspect_ratio' => '16:9')
    end

    it 'sends a source image as a subject reference' do
      context.paint('The same person', model: 'image-01', provider: :minimax, assume_model_exists: true,
                                       with: 'https://example.com/person.jpg')

      expect(sent_body(url)['subject_reference']).to eq(
        [{ 'type' => 'character', 'image_file' => 'https://example.com/person.jpg' }]
      )
    end

    it 'refuses a mask, which the endpoint has no field for' do
      expect do
        context.paint('A cat', model: 'image-01', provider: :minimax, assume_model_exists: true,
                               with: fixture('ruby.png'), mask: fixture('ruby.png'))
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /mask/)
    end
  end

  describe 'videos' do
    let(:url) { 'https://api.minimax.io/v2/video_generation' }
    let(:protocol) { RubyLLM::Protocols::MiniMax.new(provider) }

    before { stub_json(:post, url, task_id: '42', base_resp: { status_code: 0, status_msg: 'success' }) }

    it 'defaults the settings the endpoint requires' do
      job = context.animate_later('A wave', model: 'MiniMax-H3-Lite', provider: :minimax, assume_model_exists: true)

      expect(sent_body(url)).to include('resolution' => '768P', 'duration' => 5, 'ratio' => '16:9')
      expect(job.id).to eq('42')
      expect(job.duration).to eq(5)
    end

    it 'sends one image as the first frame, with no ratio' do
      context.animate_later('A wave', model: 'MiniMax-H3', provider: :minimax, assume_model_exists: true,
                                      with: 'https://example.com/a.jpg')

      body = sent_body(url)
      expect(body['content'].last).to eq(
        'type' => 'image_url', 'image_url' => { 'url' => 'https://example.com/a.jpg' }, 'role' => 'first_frame'
      )
      expect(body).not_to have_key('ratio')
    end

    it 'sends several attachments as references, and uploads by mm_file' do
      upload = RubyLLM::UploadedFile.new(id: '7', provider: 'minimax', filename: 'a.png', mime_type: 'image/png')
      context.animate_later('A wave', model: 'MiniMax-H3', provider: :minimax, assume_model_exists: true,
                                      with: [upload, 'https://example.com/v.mp4'])

      expect(sent_body(url)['content'].drop(1)).to eq(
        [
          { 'type' => 'image_url', 'image_url' => { 'url' => 'mm_file://7' }, 'role' => 'reference_image' },
          { 'type' => 'video_url', 'video_url' => { 'url' => 'https://example.com/v.mp4' },
            'role' => 'reference_video' }
        ]
      )
    end

    it 'refuses a status response without a task' do
      response = instance_double(Faraday::Response, body: { 'base_resp' => { 'status_code' => 0 } })

      expect { protocol.parse_video_job_status(response) }.to raise_error(RubyLLM::Error, /video task/)
    end

    it 'refuses an attachment of a kind the endpoint cannot use' do
      expect do
        context.animate_later('A wave', model: 'MiniMax-H3', provider: :minimax, assume_model_exists: true,
                                        with: 'https://example.com/report.pdf')
      end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'refuses a typed attachment that fits no reference kind' do
      expect do
        context.animate_later('A wave', model: 'MiniMax-H3', provider: :minimax, assume_model_exists: true,
                                        with: 'https://example.com/bundle.zip')
      end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'sends an attachment with no type as an image' do
      stub_request(:get, 'https://example.com/frame').to_return(status: 200, body: "\x00\x01".b)

      context.animate_later('A wave', model: 'MiniMax-H3', provider: :minimax, assume_model_exists: true,
                                      with: 'https://example.com/frame')

      expect(sent_body(url)['content'].last['role']).to eq('first_frame')
    end

    it 'reads the task states of a running and a failed job' do
      statuses = {
        'running' => { status: :pending },
        'failed' => { status: :failed, error: 'blocked' }
      }

      statuses.each do |status, expected|
        response = instance_double(Faraday::Response, body: { 'task' => { 'status' => status,
                                                                          'error' => { 'message' => 'blocked' } } })
        expect(protocol.parse_video_job_status(response)).to include(**expected)
      end
    end
  end

  describe 'speech' do
    let(:url) { 'https://api.minimax.io/v1/t2a_v2' }

    it 'decodes the hex audio and names the format and voice' do
      stub_json(:post, url, data: { audio: '4944', status: 2 }, extra_info: { usage_characters: 2 },
                            base_resp: { status_code: 0, status_msg: 'success' })

      speech = context.speak('Hi', model: 'speech-2.8-turbo', provider: :minimax, assume_model_exists: true,
                                   voice: 'Calm', format: 'flac')

      expect(speech.data.b).to eq('ID'.b)
      expect(speech.format).to eq('flac')
      expect(sent_body(url)).to include(
        'voice_setting' => { 'voice_id' => 'Calm' }, 'audio_setting' => { 'format' => 'flac' }, 'output_format' => 'hex'
      )
    end
  end

  describe 'speech settings' do
    it 'fetches the audio when the request asked for a URL' do
      stub_request(:get, 'https://cdn.example.com/a.mp3').to_return(status: 200, body: 'ID3')
      stub_json(:post, 'https://api.minimax.io/v1/t2a_v2', data: { audio: 'https://cdn.example.com/a.mp3' },
                                                           base_resp: { status_code: 0, status_msg: 'success' })

      speech = context.speak('Hi', model: 'speech-2.8-turbo', provider: :minimax, assume_model_exists: true,
                                   provider_options: { output_format: 'url' })

      expect(speech.data).to eq('ID3')
    end

    it 'reports the voice and format the request really used' do
      stub_json(:post, 'https://api.minimax.io/v1/t2a_v2', data: { audio: '4944' },
                                                           extra_info: { audio_format: 'flac' },
                                                           base_resp: { status_code: 0, status_msg: 'success' })

      speech = context.speak('Hi', model: 'speech-2.8-turbo', provider: :minimax, assume_model_exists: true,
                                   provider_options: { voice_setting: { voice_id: 'Calm' },
                                                       audio_setting: { format: 'flac' } })

      expect(speech).to have_attributes(voice: 'Calm', format: 'flac', mime_type: 'audio/flac')
    end
  end

  describe 'transcription' do
    let(:url) { 'https://api.minimax.io/v1/speech_to_text' }

    it 'hints the language in a header and asks for verbose_json when labelling speakers' do
      stub_request(:post, url).with(headers: { 'language' => 'en' })
                              .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
                                text: 'Hi.', duration: 1.5, n_speakers: 1,
                                segments: [{ id: 0, start: 0.0, end: 1.0, speaker: 'S1', text: 'Hi.' }]
                              }.to_json)

      transcription = context.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax,
                                                              assume_model_exists: true, language: 'en',
                                                              speaker_names: [])

      expect(a_request(:post, url).with { |request| request.body.include?('verbose_json') }).to have_been_made
      expect(transcription.duration).to eq(1.5)
      expect(transcription.segments.first.speaker).to eq('S1')
    end

    it 'puts word level units in words' do
      stub_request(:post, url).to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
        text: 'Hi', segments: [{ id: 0, start: 0.0, end: 1.0, speaker: 'S1', text: 'Hi' }]
      }.to_json)

      transcription = context.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax,
                                                              assume_model_exists: true, timestamps: :word)

      expect(a_request(:post, url).with { |request| request.body.include?('timestamp_level') }).to have_been_made
      expect(transcription.words.first.text).to eq('Hi')
      expect(transcription.segments).to be_nil
    end

    it 'refuses a granularity it does not have' do
      expect do
        context.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax, assume_model_exists: true,
                                                timestamps: :character)
      end
        .to raise_error(ArgumentError, /word or segment/)
    end

    it 'returns subtitle formats as the transcript text' do
      stub_request(:post, url).to_return(status: 200, headers: { 'Content-Type' => 'text/plain' }, body: "1\nHi\n")

      transcription = context.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax,
                                                              assume_model_exists: true, format: 'srt')

      expect(transcription.text).to eq("1\nHi\n")
    end
  end

  describe 'files' do
    it 'reads the nested file object' do
      stub_json(:get, 'https://api.minimax.io/v1/files/retrieve?file_id=9',
                file: { file_id: 9, bytes: 3, created_at: 1_700_000_000, filename: 'a.txt', purpose: 't2a_async' },
                base_resp: { status_code: 0, status_msg: 'success' })

      file = RubyLLM::UploadedFile.find('9', provider: :minimax, context:)

      expect(file).to have_attributes(id: '9', filename: 'a.txt', byte_size: 3, purpose: 't2a_async',
                                      downloadable: true)
    end

    it 'marks an uploaded input as not downloadable' do
      stub_json(:get, 'https://api.minimax.io/v1/files/retrieve?file_id=9',
                file: { file_id: 9, purpose: 't2a_async_input' }, base_resp: { status_code: 0, status_msg: 'success' })

      expect(RubyLLM::UploadedFile.find('9', provider: :minimax, context:).downloadable).to be(false)
    end

    it 'refuses a response without a file' do
      stub_json(:get, 'https://api.minimax.io/v1/files/retrieve?file_id=9', base_resp: { status_code: 0 })

      expect { RubyLLM::UploadedFile.find('9', provider: :minimax, context:) }
        .to raise_error(RubyLLM::Error, /did not return a file/)
    end
  end

  describe 'live', :live do
    before { skip_without_cassette_or_key('MINIMAX_API_KEY') }

    it 'streams a transcription' do
      chunks = []
      transcription = RubyLLM.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax,
                                                              assume_model_exists: true) do |chunk|
        chunks << chunk
      end

      expect(chunks.select(&:delta?).map(&:delta).join).to eq(transcription.text)
      expect(chunks.last).to be_done
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.duration).to be > 0
    end

    it 'labels speakers' do
      transcription = RubyLLM.transcribe(fixture('ruby.wav'), model: 'asr-1.0', provider: :minimax,
                                                              assume_model_exists: true, speaker_names: [])

      expect(transcription.segments.first.speaker).to eq('S1')
      expect(transcription.segments.first.start).to be_a(Numeric)
    end

    it 'keeps a person from a reference image in a new scene' do
      image = RubyLLM.paint(
        'The same person reading a book in a library',
        model: 'image-01', provider: :minimax, assume_model_exists: true,
        with: 'https://cdn.hailuoai.com/prod/2025-08-12-17/video_cover/1754990600020238321-411603868533342214-cover.jpg'
      )

      expect(image.to_blob.bytesize).to be > 1000
    end

    it 'uploads a file' do
      file = RubyLLM.upload(fixture('ruby.txt'), provider: :minimax, purpose: 't2a_async_input')

      expect(file.id).to be_present
      expect(file).to have_attributes(filename: 'ruby.txt', purpose: 't2a_async_input', byte_size: 17)
    end

    it 'downloads a generated file' do
      downloaded = RubyLLM.download('461627831296431', provider: :minimax)

      expect(downloaded.bytesize).to be > 1000
    end
  end
end
