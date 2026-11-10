# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Meta do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.meta_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:meta) }
  let(:responses_url) { 'https://api.meta.ai/v1/responses' }

  def context
    RubyLLM.context { |context_config| context_config.meta_api_key = 'test-key' }
  end

  def stub_response(output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Hi' }] }],
                    usage: { input_tokens: 12, output_tokens: 3, total_tokens: 15 })
    stub_request(:post, responses_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'resp_1', object: 'response', status: 'completed', model: model_id, output: output, usage: usage
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, responses_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Meta's dialect of the Responses API" do
    expect(described_class.protocols).to include(responses: described_class::Responses)
    expect(described_class::Responses.superclass).to eq(RubyLLM::Protocols::Responses)
  end

  it "stores files through Meta's OpenAI-shaped Files API" do
    expect(described_class.protocols).to include(files: RubyLLM::Protocols::OpenAI::Files)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[meta_api_key meta_api_base])
    expect(described_class.configuration_requirements).to eq(%i[meta_api_key])
  end

  it 'defaults to the Meta Model API and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.meta.ai/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.meta_api_base = 'https://meta-proxy.example.com/v1'

    expect(provider.api_base).to eq('https://meta-proxy.example.com/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(meta: described_class)
    expect(described_class).to be_remote
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev meta catalog' do
    expect(described_class.models_dev_provider_ids).to eq(%w[meta])
    expect(RubyLLM.models.find(model_id, provider: :meta).context_window).to eq(1_048_576)
  end

  describe 'chat' do
    it 'runs stateless, replays encrypted reasoning, and names the end user' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_end_user('user-42').ask('Hello')

      expect(sent_body).to include(
        'store' => false,
        'include' => ['reasoning.encrypted_content'],
        'safety_identifier' => 'user-42'
      )
    end

    it 'keeps the encrypted reasoning, and counts cached input and reasoning tokens' do
      stub_response(
        output: [
          { type: 'reasoning', id: 'rs_1', summary: [], encrypted_content: 'sealed' },
          { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: '391' }] }
        ],
        usage: { input_tokens: 100, output_tokens: 30, total_tokens: 130,
                 input_tokens_details: { cached_tokens: 80 }, output_tokens_details: { reasoning_tokens: 20 } }
      )

      response = context.chat(model: model_id, provider: :meta).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.signature).to eq('sealed')
      expect(response.tokens.input).to eq(20)
      expect(response.tokens.cache_read).to eq(80)
      expect(response.tokens.thinking).to eq(20)
    end

    it 'sets the reasoning effort' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_thinking(effort: :max).ask('Hello')

      expect(sent_body['reasoning']).to eq('effort' => 'max')
    end

    it 'sends a cache key and retention without breakpoints' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_caching(key: 'docs', ttl: '24h').ask('Hello')

      expect(sent_body).to include('prompt_cache_key' => 'docs', 'prompt_cache_retention' => '24h')
      expect(sent_body.to_json).not_to include('prompt_cache_breakpoint')
    end

    it 'spells a retention given in seconds' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_caching(ttl: 86_400).ask('Hello')

      expect(sent_body).to include('prompt_cache_retention' => '24h')
    end

    it 'rejects cache options Meta does not take' do
      chat = context.chat(model: model_id, provider: :meta).with_caching(mode: 'explicit')

      expect { chat.ask('Hello') }.to raise_error(ArgumentError, /accepts :key and :ttl/)
    end

    it 'grounds answers in web search, and refuses other provider tools' do
      stub_response

      context.chat(model: model_id, provider: :meta).with_provider_tools(:web_search).ask('News?')

      expect(sent_body['tools']).to eq([{ 'type' => 'web_search' }])
      expect do
        context.chat(model: model_id, provider: :meta).with_provider_tools(:code_execution).ask('Run it')
      end.to raise_error(RubyLLM::UnsupportedServerToolError)
    end
  end

  it 'sends remote images inline, because Meta refuses to fetch many of them' do
    png = File.binread(File.expand_path('../../fixtures/ruby.png', __dir__))
    stub_request(:get, 'https://example.com/ruby')
      .to_return(status: 200, body: png, headers: { 'Content-Type' => 'image/png' })
    stub_response

    context.chat(model: model_id, provider: :meta).ask('What is this?', with: 'https://example.com/ruby')

    data_uri = "data:image/png;base64,#{Base64.strict_encode64(png)}"
    expect(sent_body['input'].last['content'].last).to eq('type' => 'input_image', 'image_url' => data_uri)
  end

  it 'counts input tokens with the Responses endpoint' do
    stub_request(:post, 'https://api.meta.ai/v1/responses/input_tokens')
      .to_return(status: 200, body: { object: 'response.input_tokens', input_tokens: 7 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect(context.chat(model: model_id, provider: :meta).count_tokens('Hello')).to eq(7)
  end

  describe 'attachments' do
    let(:protocol) { described_class::Responses.new(provider, RubyLLM.models.find('muse-spark-1.2', provider: :meta)) }

    it 'sends local and remote videos inline as data URLs' do
      stub_request(:get, 'https://example.com/clip.mp4')
        .to_return(status: 200, body: 'mp4 bytes', headers: { 'Content-Type' => 'video/mp4' })
      remote = RubyLLM::Attachment.new('https://example.com/clip.mp4')
      local = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby_clip.mp4', __dir__))

      expect(protocol.send(:render_content, 'Watch this', [remote, local]).drop(1)).to eq(
        [
          { type: 'input_video', video_url: "data:video/mp4;base64,#{Base64.strict_encode64('mp4 bytes')}" },
          { type: 'input_video', video_url: local.for_llm }
        ]
      )
    end

    it 'sends audio inline with its format' do
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.mp3', __dir__))

      expect(protocol.send(:render_content, 'Hear this', [audio]).last)
        .to eq(type: 'input_audio', input_audio: { data: audio.encoded, format: 'mp3' })
    end

    it 'keeps rendering uploaded video as a file reference' do
      file = RubyLLM::UploadedFile.new(id: 'file-1', provider: 'meta', mime_type: 'video/mp4')

      expect(protocol.send(:render_content, 'Watch this', [RubyLLM::Attachment.new(file)]).last)
        .to eq(type: 'input_file', file_id: 'file-1')
    end
  end

  describe 'transcription' do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
    let(:transcription_model) { model_for(:meta, :transcription) }

    def transcribe_url = 'https://api.meta.ai/v1/asr/transcribe'

    def transcribe(**, &)
      RubyLLM.transcribe(audio_path, model: transcription_model, provider: :meta, context:, **, &)
    end

    def request_settings(request)
      request.body.to_s[/name="request".*?\r\n\r\n(.*?)\r\n--/m, 1].then { |json| JSON.parse(json) }
    end

    def stub_transcription(body)
      stub_request(:post, transcribe_url)
        .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    def stub_transcription_stream(*events)
      body = events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join
      stub_request(:post, transcribe_url)
        .with(headers: { 'Accept' => 'text/event-stream' })
        .to_return(status: 200, body:, headers: { 'Content-Type' => 'text/event-stream' })
    end

    it 'posts the settings and the audio as the request and audio parts' do
      stub_transcription(transcript: 'Hello', audioDurationMs: 1500, turns: [])

      result = transcribe(language: 'English', prompt: 'Ruby')

      expect(result).to have_attributes(text: 'Hello', duration: 1.5, segments: nil)
      expect(a_request(:post, transcribe_url).with do |request|
        expect(request.body.to_s).to include('name="audio"')
        expect(request_settings(request)).to eq(
          'model' => transcription_model, 'audioEncoding' => 'WAV', 'languageBias' => ['English'],
          'keywords' => ['Ruby']
        )
      end).to have_been_made
    end

    it 'turns on diarization for speaker labels and reads turns as segments in seconds' do
      stub_transcription(transcript: 'Hi. Bye.', audioDurationMs: 2000, turns: [
                           { turnId: 1, startMs: 500, endMs: 1200, transcript: 'Hi.', speaker: 'A' },
                           { turnId: 2, startMs: 1300, endMs: 2000, transcript: 'Bye.', speaker: 'B' }
                         ])

      result = transcribe(speaker_names: [])

      expect(result.segments.map { |segment| [segment.text, segment.start, segment.end, segment.speaker] })
        .to eq([['Hi.', 0.5, 1.2, 'A'], ['Bye.', 1.3, 2.0, 'B']])
      expect(a_request(:post, transcribe_url).with { |request| request_settings(request)['mode'] == 'DIARIZATION' })
        .to have_been_made
    end

    it 'asks for timed turns when segment timestamps are requested' do
      stub_transcription(transcript: 'Hi', audioDurationMs: 900, turns: [])

      transcribe(timestamps: :segment)

      expect(a_request(:post, transcribe_url).with { |request| request_settings(request)['mode'] == 'ENDPOINTING' })
        .to have_been_made
    end

    it 'refuses word timestamps, which Meta does not report' do
      expect { transcribe(timestamps: :word) }.to raise_error(ArgumentError, /must be segment/)
    end

    it 'refuses named speakers and the options its request cannot carry' do
      expect { transcribe(speaker_names: ['Alice']) }.to raise_error(ArgumentError, /named_speakers/)
      expect { transcribe(format: 'text') }.to raise_error(ArgumentError, /format/)
      expect { transcribe(temperature: 0.2) }.to raise_error(ArgumentError, /temperature/)
    end

    it 'streams a single transcript as partials and one final delta' do
      stub_transcription_stream(
        { type: 'transcript', transcript: 'Ruby', final: false, audioProcessedMs: 800 },
        { type: 'transcript', transcript: 'Ruby is fun', final: false, audioProcessedMs: 1600 },
        { type: 'transcript', transcript: 'Ruby is fun.', final: true, audioProcessedMs: 1700 }
      )
      chunks = []

      result = transcribe { |chunk| chunks << chunk }

      expect(chunks.map(&:type)).to eq(%i[partial partial delta done])
      expect(chunks.first(2).map(&:text)).to eq(['Ruby', 'Ruby is fun'])
      expect(chunks[2].delta).to eq('Ruby is fun.')
      expect(result).to have_attributes(text: 'Ruby is fun.', duration: 1.7, segments: nil)
      expect(a_request(:post, transcribe_url).with do |request|
        request_settings(request)['emitAudioProgress'] == false
      end).to have_been_made
    end

    it 'streams completed turns as segments labelled with their speaker, in spoken order' do
      stub_transcription_stream(
        { type: 'speechStart', turnId: 0, audioProcessedMs: 100 },
        { type: 'transcript', transcript: 'Hi', final: false, audioProcessedMs: 500 },
        { type: 'speaker', label: 'A', audioProcessedMs: 900 },
        { type: 'speechEnd', turnId: 0, audioProcessedMs: 1000 },
        { type: 'speechStart', turnId: 1, audioProcessedMs: 1100 },
        { type: 'speaker', label: 'B', audioProcessedMs: 1800 },
        { type: 'speechEnd', turnId: 1, audioProcessedMs: 1900 },
        { type: 'speechComplete', turnId: 1, transcript: 'Bye.', audioProcessedMs: 1900 },
        { type: 'speechComplete', turnId: 0, transcript: ' Hi. ', audioProcessedMs: 1000 },
        { type: 'speechStart', turnId: 2, audioProcessedMs: 1950 },
        { type: 'speechComplete', turnId: 2, transcript: ' ', audioProcessedMs: 1960 },
        { type: 'transcript', transcript: '', final: true, audioProcessedMs: 2000 }
      )
      chunks = []

      result = transcribe(speaker_names: []) { |chunk| chunks << chunk }

      expect(chunks.select(&:segment?).map { |chunk| [chunk.segment.text, chunk.segment.speaker, chunk.delta] })
        .to eq([['Hi.', 'A', 'Hi.'], ['Bye.', 'B', ' Bye.']])
      expect(chunks.last).to be_done
      expect(result.text).to eq('Hi. Bye.')
      expect(result.segments.map { |segment| [segment.start, segment.end] }).to eq([[0.1, 1.0], [1.1, 1.9]])
      expect(result.duration).to eq(2.0)
    end

    it 'raises on a terminal error event' do
      stub_transcription_stream({ type: 'error', message: 'Transcription failed', sessionId: 's' })

      expect { transcribe { |chunk| chunk } }.to raise_error(RubyLLM::Error, /Transcription failed/)
    end

    it 'raises when the stream stops with a turn unfinished' do
      stub_transcription_stream({ type: 'speechStart', turnId: 0, audioProcessedMs: 100 })

      expect { transcribe { |chunk| chunk } }.to raise_error(RubyLLM::Error, /before its final transcript/)
    end
  end

  describe 'files' do
    it 'uploads with an expiry and reads the file back' do
      upload = stub_request(:post, 'https://api.meta.ai/v1/files')
               .with { |request| request.body.to_s.include?('name="expires_after[seconds]"') }
               .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
                 id: 'file-1', bytes: 6, created_at: 1_794_255_626, expires_at: nil, filename: 'ruby.txt',
                 object: 'file', purpose: 'user_data', status: 'uploaded'
               }.to_json)
      download = stub_request(:get, 'https://api.meta.ai/v1/files/file-1/content').to_return(status: 200, body: 'hello')
      path = File.expand_path('../../fixtures/ruby.txt', __dir__)

      file = RubyLLM.upload(path, provider: :meta, context:, purpose: 'user_data', expires_in: 3600)

      expect(file).to have_attributes(id: 'file-1', byte_size: 6, purpose: 'user_data', provider: 'meta')
      expect(RubyLLM::UploadedFile.download('file-1', provider: :meta, context:).to_blob).to eq('hello')
      expect(upload).to have_been_requested
      expect(download).to have_been_requested
    end
  end
end
