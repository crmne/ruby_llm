# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Speech do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:deepgram, :streaming_speech) }
  let(:provider) { RubyLLM::Providers::Deepgram.new(RubyLLM.config) }
  let(:protocol) { RubyLLM::Protocols::Deepgram.new(provider, RubyLLM.models.find(model, provider: :deepgram)) }
  let(:audio) { "ID3\xFF\x00audio".b }
  let(:url) { "https://api.deepgram.com/v1/speak?encoding=mp3&model=#{model}" }

  def stream(&)
    protocol.speak('Hello Ruby.', model:, voice: nil, format: nil, &)
  end

  def stub_stream(chunks, status: 200, content_type: 'audio/mpeg', expose_env: true)
    allow(provider.connection).to receive(:post) do |*, **, &configure|
      request = Faraday::Request.create(:post)
      request.options = Faraday::RequestOptions.new
      configure.call(request)
      env = Faraday::Env.from(status:, response_headers: Faraday::Utils::Headers.new('content-type' => content_type))
      bytes = 0
      chunks.each do |chunk|
        bytes += chunk.bytesize
        request.options.on_data.call(chunk, bytes, expose_env ? env : nil)
      end
      Faraday::Response.new(env)
    end
  end

  it 'yields consecutive binary chunks before the request finishes and returns the complete speech' do
    stub_stream([audio, 'tail'])
    chunks = []

    speech = stream do |chunk|
      expect(chunk).to be_a(RubyLLM::SpeechChunk)
      expect(chunk.format).to eq('mp3')
      expect(chunk.mime_type).to eq('audio/mpeg')
      expect(chunk.data.encoding).to eq(Encoding::BINARY)
      chunks << chunk.to_blob
    end

    expect(chunks).to eq([audio, 'tail'])
    expect(speech).to be_a(described_class)
    expect(speech.to_blob).to eq("#{audio}tail")
    expect(speech.model).to eq(model)
    expect(speech.voice).to eq('thalia')
  end

  it 'buffers adapters without response metadata until the audio response is validated' do
    stub_stream([audio, 'tail'], expose_env: false)
    chunks = []

    speech = stream { |chunk| chunks << chunk.data }

    expect(chunks).to eq(["#{audio}tail"])
    expect(speech.data).to eq(chunks.join)
  end

  it 'uses the Faraday 1 callback with its two arguments and buffered validation' do
    stub_const('Faraday::VERSION', '1.10.4')
    stub_stream([audio, 'tail'], expose_env: false)
    chunks = []

    speech = stream { |chunk| chunks << chunk.data }

    expect(chunks.join).to eq(speech.data)
    expect(speech.data).to eq("#{audio}tail")
  end

  it 'discards a failed attempt buffered by an adapter without response metadata' do
    state = RubyLLM::Protocol::Streaming::StreamState.new
    progress = {}
    handler = protocol.send(:binary_on_data, state, progress) { raise 'Audio is not validated yet' }

    handler.call('failed response', 15)
    handler.call(audio, audio.bytesize)

    expect(state.buffer).to eq(audio)
    expect(progress).to be_empty
  end

  it 'never yields a split JSON error response as audio' do
    stub_stream(['{"err_msg":', '"Too many requests"}'], status: 429, content_type: 'application/json')
    chunks = []

    expect { stream { |chunk| chunks << chunk } }.to raise_error(RubyLLM::RateLimitError, 'Too many requests')
    expect(chunks).to be_empty
  end

  it 'rejects JSON error responses when the adapter omits metadata during delivery' do
    stub_stream(['{"err_msg":', '"Synthesis failed"}'], content_type: 'application/json', expose_env: false)
    chunks = []

    expect { stream { |chunk| chunks << chunk } }.to raise_error(RubyLLM::ServerError, 'Synthesis failed')
    expect(chunks).to be_empty
  end

  it 'does not treat successful JSON or HTML as binary audio' do
    stub_stream(['<html>Service unavailable</html>'], content_type: 'text/html')

    expect { stream { raise 'audio must not be delivered' } }
      .to raise_error(RubyLLM::Error, /Expected an audio response/)
  end

  it 'retries a failure before audio delivery without retaining its error body' do
    RubyLLM.config.max_retries = 1
    request = stub_request(:post, url).to_return(
      { status: 429, headers: { 'content-type' => 'application/json' }, body: '{"err_msg":"Try again"}' },
      { status: 200, headers: { 'content-type' => 'audio/mpeg' }, body: audio }
    )
    chunks = []

    speech = stream { |chunk| chunks << chunk.data }

    expect(request).to have_been_requested.twice
    expect(chunks.join).to eq(audio)
    expect(speech.data).to eq(audio)
    expect(speech.ruby_llm_usage_entries.map(&:status)).to eq(%i[failed succeeded])
  end

  it 'preserves caller exceptions and does not retry after delivering audio' do
    RubyLLM.config.max_retries = 2
    request = stub_request(:post, url)
              .to_return(status: 200, headers: { 'content-type' => 'audio/mpeg' }, body: audio)
    error = RubyLLM::ServerError.new('Playback stopped')

    expect { stream { raise error } }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(request).to have_been_requested.once
  end

  it 'forwards the block through a context and reports the complete result in instrumentation' do
    events = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = events }
    stub_request(:post, url).to_return(status: 200, headers: { 'content-type' => 'audio/mpeg' }, body: audio)
    chunks = []

    speech = context.speak('Hello Ruby.', model:, provider: :deepgram) { |chunk| chunks << chunk.data }

    expect(chunks.join).to eq(speech.data)
    event = events.events.find { |name, _| name == 'speech.ruby_llm' }.last
    expect(event).to include(streaming: true, result: speech, audio_bytes: audio.bytesize)
    expect(speech.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
  end

  it 'rejects a block for a speech protocol without streaming support' do
    expect do
      RubyLLM.speak('Hello Ruby.', model: model_for(:gemini, :speech), provider: :gemini) { |_chunk| nil }
    end.to raise_error(RubyLLM::Error, /doesn't support streaming speech/)
  end

  it 'uses the ElevenLabs streaming endpoint with the selected voice and output format' do
    model = model_for(:elevenlabs, :streaming_speech)
    request = stub_request(:post,
                           'https://api.elevenlabs.io/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb/stream?output_format=pcm_24000')
              .with(body: { text: 'Hello Ruby.', model_id: model, voice_settings: { stability: 0.4 } })
              .to_return(status: 200, headers: { 'content-type' => 'audio/pcm' }, body: audio)
    chunks = []

    speech = RubyLLM.speak('Hello Ruby.', model:, provider: :elevenlabs, format: 'pcm_24000',
                                          provider_options: { voice_settings: { stability: 0.4 } }) do |chunk|
      chunks << chunk
    end

    expect(request).to have_been_requested.once
    expect(speech.format).to eq('pcm')
    expect(chunks.first.format).to eq('pcm')
    expect(chunks.map(&:data).join).to eq(audio)
  end

  it 'streams Azure speech through the configured deployment URL' do
    context = RubyLLM.context do |config|
      config.azure_api_base = 'https://contoso.openai.azure.com/openai/deployments/speech?api-version=2024-10-21'
    end
    request = stub_request(:post,
                           'https://contoso.openai.azure.com/openai/deployments/speech/audio/speech?api-version=2024-10-21')
              .to_return(status: 200, headers: { 'content-type' => 'audio/mpeg' }, body: audio)
    chunks = []

    speech = context.speak('Hello Ruby.', model: model_for(:azure, :azure_speech), provider: :azure) do |chunk|
      chunks << chunk.data
    end

    expect(request).to have_been_requested.once
    expect(chunks.join).to eq(speech.data)
  end

  TEST_MODELS.fetch(:streaming_speech).reject { |entry| entry[:provider] == :xai }.each do |entry|
    provider = entry.fetch(:provider)

    it "streams speech from #{provider}", :live do
      skip_without_cassette_or_key("#{provider.to_s.upcase}_API_KEY")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      arrivals = []
      chunks = []
      result = RubyLLM.speak('Ruby makes it easy to build applications with streaming audio. ' \
                             'You can start listening while the rest of this sentence is generated.',
                             model: model_for(provider, :streaming_speech), provider:, voice: entry[:voice]) do |chunk|
        arrivals << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
        chunks << chunk.data
      end
      finished = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(result).to be_a(described_class)
      expect(result.to_blob.bytesize).to be > 1000
      expect(chunks.join).to eq(result.to_blob)
      expect(chunks).not_to be_empty
      if VCR.current_cassette.recording?
        expect(arrivals.first).to be < finished
        RSpec.configuration.reporter.message(
          "#{provider} audio: #{chunks.size} chunks, first #{arrivals.first.round(3)}s, complete #{finished.round(3)}s"
        )
      end
    end
  end
end
