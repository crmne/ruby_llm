# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Deepgram do
  include_context 'with configured RubyLLM'

  let(:provider) { described_class.new(RubyLLM.config) }

  describe '#api_base' do
    it 'talks to the Deepgram API' do
      expect(provider.api_base).to eq('https://api.deepgram.com')
    end

    it 'honors a configured base' do
      RubyLLM.config.deepgram_api_base = 'https://deepgram.example.com'

      expect(provider.api_base).to eq('https://deepgram.example.com')
    ensure
      RubyLLM.config.deepgram_api_base = nil
    end
  end

  describe '#headers' do
    it 'authenticates with a Token authorization header' do
      RubyLLM.config.deepgram_api_key = 'deepgram-key'

      expect(provider.headers).to eq('Authorization' => 'Token deepgram-key')
    end
  end

  describe '#parse_error' do
    it 'reads the err_msg Deepgram reports' do
      response = instance_double(
        Faraday::Response,
        body: { 'err_code' => 'INVALID_AUTH', 'err_msg' => 'Invalid credentials.', 'request_id' => 'uuid' }
      )

      expect(provider.parse_error(response)).to eq('Invalid credentials.')
    end

    it 'falls back to the generic parser' do
      response = instance_double(Faraday::Response, body: { 'message' => 'Bad request' })

      expect(provider.parse_error(response)).to eq('Bad request')
    end
  end

  describe 'the transcription requests it sends' do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
    let(:listen_response) do
      {
        'metadata' => { 'duration' => 2.5 },
        'results' => { 'channels' => [{ 'alternatives' => [{ 'transcript' => 'Ruby.' }] }] }
      }
    end

    it 'uploads a local file as raw audio bytes under its own content type' do
      stub = stub_request(:post, %r{https://api\.deepgram\.com/v1/listen})
             .with(headers: { 'Content-Type' => 'audio/wav' }, body: File.binread(audio_path))
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram)

      expect(stub).to have_been_requested
    end

    it 'posts the bytes of audio given as an attachment' do
      stub_request(:post, %r{https://api\.deepgram\.com/v1/listen})
        .to_return(status: 200, body: listen_response.to_json, headers: { 'Content-Type' => 'application/json' })
      attachment = RubyLLM::Attachment.new(StringIO.new(File.binread(audio_path)), filename: 'meeting.wav')

      RubyLLM.transcribe(attachment, model: 'nova-3', provider: :deepgram)

      expect(a_request(:post, %r{https://api\.deepgram\.com/v1/listen}).with(body: File.binread(audio_path)))
        .to have_been_made
    end

    it 'hands a remote url to Deepgram as JSON rather than downloading it' do
      stub = stub_request(:post, %r{https://api\.deepgram\.com/v1/listen})
             .with(headers: { 'Content-Type' => 'application/json' },
                   body: { url: 'https://dpgr.am/spacewalk.wav' })
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe('https://dpgr.am/spacewalk.wav', model: 'nova-3', provider: :deepgram)

      expect(stub).to have_been_requested
    end

    it 'carries the transcription options in the query string' do
      stub = stub_request(:post, 'https://api.deepgram.com/v1/listen')
             .with(query: { model: 'nova-3-general', language: 'en', smart_format: 'true', utterances: 'true',
                            diarize_model: 'latest' })
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram, language: 'en',
                                     speaker_names: [])

      expect(stub).to have_been_requested
    end

    it 'carries the prompt in the query string as a key term' do
      stub = stub_request(:post, 'https://api.deepgram.com/v1/listen')
             .with(query: { model: 'nova-3-general', smart_format: 'true', utterances: 'true', keyterm: 'RubyLLM' })
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram, prompt: 'RubyLLM')

      expect(stub).to have_been_requested
    end
  end

  describe 'the speech requests it sends' do
    it 'speaks the text through the query-configured model and encoding' do
      stub = stub_request(:post, 'https://api.deepgram.com/v1/speak')
             .with(query: { model: 'aura-2-zeus-en', encoding: 'linear16', container: 'wav' },
                   body: { text: 'Ship it.' })
             .to_return(status: 200, body: 'audio bytes', headers: { 'Content-Type' => 'audio/wav' })

      speech = RubyLLM.speak('Ship it.', model: 'aura-2-thalia-en', provider: :deepgram, voice: 'zeus',
                                         format: 'wav')

      expect(stub).to have_been_requested
      expect(speech.to_blob).to eq('audio bytes')
    end
  end

  describe 'chat on the Think endpoint' do
    let(:think_url) { 'https://agent.deepgram.com/v1/think' }
    let(:long_instructions) do
      "You are a terse assistant for a fictional bakery. #{(1..300).map { |n| "Rule #{n}: be brief." }.join(' ')}"
    end

    def think_chat(model = 'think-fast')
      RubyLLM.chat(model: model, provider: :deepgram, assume_model_exists: true)
    end

    def weather_tool
      stub_const('Weather', Class.new(RubyLLM::Tool) do
        description 'Gets the current weather for one city'
        parameter :city, description: 'The city name'

        def execute(city:) = "#{city}: 15 degrees"
      end)
    end

    def stub_think
      stub_request(:post, think_url).to_return(
        status: 200,
        body: { id: 'chatcmpl-1', object: 'chat.completion', model: 'think-fast',
                choices: [{ index: 0, message: { role: 'assistant', content: 'Hi' }, finish_reason: 'stop' }],
                usage: { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15,
                         prompt_tokens_details: { cached_tokens: 5 } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    def sent_body
      body = nil
      expect(a_request(:post, think_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
      body
    end

    it 'posts to the Think host with Token authentication' do
      RubyLLM.config.deepgram_api_key = 'deepgram-key'
      stub = stub_think.with(headers: { 'Authorization' => 'Token deepgram-key' })

      think_chat.ask('Hello')

      expect(stub).to have_been_requested
    end

    it 'sends a configured base the Think path too' do
      RubyLLM.config.deepgram_api_base = 'https://deepgram.example.com/'
      stub = stub_request(:post, 'https://deepgram.example.com/v1/think').to_return(
        status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { choices: [{ message: { role: 'assistant', content: 'Hi' }, finish_reason: 'stop' }] }.to_json
      )

      think_chat.ask('Hello')

      expect(stub).to have_been_requested
    ensure
      RubyLLM.config.deepgram_api_base = nil
    end

    it 'refuses a base that already ends in the Think path' do
      RubyLLM.config.deepgram_api_base = 'https://deepgram.example.com/v1/think'

      expect { provider.api_base }.to raise_error(RubyLLM::ConfigurationError, %r{without /v1/think})
    ensure
      RubyLLM.config.deepgram_api_base = nil
    end

    it 'sends instructions as a system message' do
      stub_think

      think_chat.with_instructions('Be brief.').ask('Hello')

      expect(sent_body['messages'].first).to eq('role' => 'system', 'content' => 'Be brief.')
    end

    it 'sends no prompt cache fields, which the endpoint would reject' do
      stub_think

      think_chat.with_caching(key: 'bakery').ask('Hello')

      expect(sent_body.keys).not_to include('prompt_cache_key', 'prompt_cache_options')
    end

    it 'bills cached tokens as cache reads' do
      stub_think

      expect(think_chat.ask('Hello').tokens.cache_read).to eq(5)
    end

    it 'keeps speech and transcription on the Deepgram protocol' do
      model = RubyLLM::Model.default('nova-3', 'deepgram')

      expect(provider.protocol_for(model, operation: :transcribe)).to eq(RubyLLM::Protocols::Deepgram)
      expect(provider.protocol_for(model, operation: :speak)).to eq(RubyLLM::Protocols::Deepgram)
    end

    it 'answers from the history the application holds', :live do
      chat = think_chat

      chat.ask('My name is Ada. Reply with just OK.')
      response = chat.ask('What is my name? Reply with just the name.')

      expect(response.content).to include('Ada')
      expect(response.tokens.input).to be_positive
    end

    it 'streams chunks and reports usage', :live do
      chunks = []

      response = think_chat.ask('Count from 1 to 3.') { |chunk| chunks << chunk }

      expect(chunks.filter_map(&:content).join).to eq(response.content)
      expect(response.tokens.output).to be_positive
    end

    it 'runs a tool and sends the result back', :live do
      response = think_chat.with_tools(weather_tool).ask('What is the weather in Berlin? Use the tool.')

      expect(response.content).to match(/15|fifteen/i)
    end

    it 'runs a tool from a streamed response', :live do
      chat = think_chat.with_tools(weather_tool)

      response = chat.ask('What is the weather in Berlin? Use the tool.') { |_chunk| nil }

      expect(response.content).to match(/15|fifteen/i)
    end

    it 'takes several tool calls in one response', :live do
      chat = think_chat.with_tools(weather_tool)

      chat.ask('What is the weather in Berlin and in Paris? Call the tool once per city, both at the same time.')

      expect(chat.messages.select(&:tool_call?).map { |message| message.tool_calls.size }.max).to be >= 2
    end

    it 'sends a thinking effort as reasoning_effort' do
      stub_think

      think_chat.with_thinking(effort: :low).ask('Hello')

      expect(sent_body['reasoning_effort']).to eq('low')
    end

    it 'accepts a thinking effort on phoneLLM mini', :live do
      response = think_chat('phonellm-mini-alpha-2-fp8').with_thinking(effort: :low).ask('What is 2+2?')

      expect(response.content).to include('4')
    end

    it 'thinks when asked to and not when told not to', :live do
      question = 'A shop sells pens at 3 for 4 euros. How many euros do 27 pens cost?'

      thought = think_chat.with_thinking(effort: :low).ask(question)
      direct = think_chat.with_thinking(effort: :none).ask(question)

      expect(thought.tokens.thinking).to be_positive
      expect(direct.tokens.thinking).to eq(0)
    end

    it 'reports the cached part of a repeated prompt', :live do
      reads = Array.new(6) do
        think_chat.with_instructions(long_instructions).ask('Say hello.').tokens.cache_read
      end

      expect(reads.max).to be_positive
    end
  end

  describe 'operations Deepgram has no endpoint for' do
    it 'refuses to embed' do
      expect do
        RubyLLM.embed('Hello', model: 'nova-3', provider: :deepgram)
      end.to raise_error(RubyLLM::Error, "Deepgram doesn't support embeddings")
    end

    it 'refuses to paint' do
      expect do
        RubyLLM.paint('A ruby', model: 'nova-3', provider: :deepgram)
      end.to raise_error(RubyLLM::Error, "Deepgram doesn't support image generation")
    end

    it 'has no chat model to fall back on' do
      expect { RubyLLM.chat(provider: :deepgram) }.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  it 'routes streaming transcription through the authenticated WebSocket endpoint' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open).and_yield(socket)
    allow(socket).to receive(:each_message).and_yield(JSON.generate(type: 'Metadata', duration: 3.7))
    model = model_for(:deepgram, :websocket_transcription)
    chunks = []

    result = RubyLLM.transcribe('spec/fixtures/ruby.wav', model:, provider: :deepgram) { |chunk| chunks << chunk }

    expect(RubyLLM::Transport::WebsocketConnection).to have_received(:open).with(
      "wss://api.deepgram.com/v1/listen?model=#{model}&smart_format=true&interim_results=true",
      headers: hash_including('Authorization' => a_string_starting_with('Token ')), config: RubyLLM.config
    )
    expect(result.duration).to eq(3.7)
    expect(chunks.map(&:type)).to eq([RubyLLM::TranscriptionChunk::DONE])
  end

  describe 'audio', :live do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }

    before do
      skip_without_cassette_or_key('DEEPGRAM_API_KEY')
    end

    it 'transcribes a local file with nova-3' do
      transcription = RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram)

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.model).to eq('nova-3-general')
      expect(transcription.duration).to be > 0
      expect(transcription.words).to be_an(Array)
    end

    it 'transcribes audio Deepgram fetches from a url' do
      transcription = RubyLLM.transcribe('https://dpgr.am/spacewalk.wav', model: 'nova-3', provider: :deepgram)

      expect(transcription.text).to be_a(String)
      expect(transcription.segments).to be_an(Array)
    end

    it 'labels words with speakers when speaker names are given' do
      transcription = RubyLLM.transcribe(
        audio_path,
        model: 'nova-3',
        provider: :deepgram,
        language: 'en',
        speaker_names: []
      )

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.words.first).to have_key('speaker')
    end

    it 'speaks text with aura-2' do
      speech = RubyLLM.speak(
        'Ruby is a programming language designed for developer happiness.',
        model: 'aura-2-thalia-en',
        provider: :deepgram
      )

      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq('aura-2-thalia-en')
      expect(speech.voice).to eq('thalia')
      expect(speech.mime_type).to eq('audio/mpeg')
    end

    it 'swaps the voice inside the model id and honors the format' do
      speech = RubyLLM.speak(
        'Save this as a WAV file.',
        model: 'aura-2-thalia-en',
        provider: :deepgram,
        voice: 'zeus',
        format: 'wav'
      )

      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq('aura-2-zeus-en')
      expect(speech.voice).to eq('zeus')
      expect(speech.format).to eq('wav')
    end

    it 'lists the listening and speaking models' do
      models = provider.list_models

      expect(models.map(&:id)).to include('nova-3-general', 'aura-2-thalia-en')
      expect(models.map(&:id)).to eq(models.map(&:id).uniq)
      expect(models.find { |model| model.id == 'nova-3-general' }.capabilities).to eq(['transcription'])
    end
  end
end
