# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../support/websocket_cassette'

RSpec.describe RubyLLM::Protocols::Gemini::LiveTranscription do
  include_context 'with configured RubyLLM'

  let(:protocol) { described_class.new(RubyLLM::Providers::Gemini.new(RubyLLM.config)) }
  let(:model) { model_for(:gemini, :live_transcription) }
  let(:path) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }
  let(:audio) { RubyLLM::Transcription::WavAudio.new(File.binread(path)) }
  let(:events) do
    [{ 'setupComplete' => {} }, { 'serverContent' => { 'interimInputTranscription' => { 'text' => 'Hel' } } },
     { 'serverContent' => { 'inputTranscription' => { 'text' => 'Hello.' } },
       'usageMetadata' => { 'promptTokenCount' => 12, 'candidatesTokenCount' => 2 } },
     { 'serverContent' => { 'generationComplete' => true } }]
  end

  def stub_socket(incoming)
    socket = instance_double(RubyLLM::Transport::WebsocketConnection, close: nil, send_text: nil)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open).and_yield(socket)
    allow(socket).to receive(:each_message) do |&block|
      incoming.each { |event| block.call(JSON.generate(event)) }
    end
    socket
  end

  it 'keeps partial text separate and waits for generation completion before returning final text and usage' do
    socket = stub_socket(events)
    chunks = []

    result = RubyLLM.transcribe(path, model:, provider: :gemini) { |chunk| chunks << chunk }

    expect(result).to have_attributes(text: 'Hello.', duration: 3.7, words: nil)
    expect(result.tokens).to have_attributes(input: 12, output: 2)
    expect(chunks.map(&:type)).to eq([RubyLLM::TranscriptionChunk::PARTIAL,
                                      RubyLLM::TranscriptionChunk::DELTA, RubyLLM::TranscriptionChunk::DONE])
    expect(chunks.filter_map(&:delta).join).to eq(result.text)
    expect(socket).to have_received(:close).once
  end

  it 'does not mark an input transcript complete when its generation boundary never arrives' do
    stub_socket(events[0...-1])
    chunks = []

    expect { RubyLLM.transcribe(path, model:, provider: :gemini) { |chunk| chunks << chunk } }
      .to raise_error(RubyLLM::Error, /before generation completed/)
    expect(chunks).not_to include(have_attributes(done?: true))
  end

  it 'supports returning a completed Live transcript without a consumer block' do
    stub_socket(events)

    expect(RubyLLM.transcribe(path, model:, provider: :gemini).text).to eq('Hello.')
  end

  it 'preserves provider errors and consumer exceptions without starting a second connection' do
    stub_socket([{ 'error' => { 'message' => 'Unsupported configuration' } }])
    expect { RubyLLM.transcribe(path, model:, provider: :gemini) }.to raise_error(/Unsupported configuration/)

    stub_socket(events)
    expect { RubyLLM.transcribe(path, model:, provider: :gemini) { raise 'consumer stopped' } }
      .to raise_error('consumer stopped')
    expect(RubyLLM::Transport::WebsocketConnection).to have_received(:open).twice
  end

  it 'sends complete PCM frames between explicit activity boundaries and preserves every input byte' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    frames = []
    allow(socket).to receive(:send_text) { |message| frames << JSON.parse(message) }
    sample = instance_double(RubyLLM::Transcription::WavAudio, sample_rate: 11_025, data: 'ab'.b * 2000)

    protocol.send_transcription_audio(socket, sample)

    expect(frames.first).to eq('realtimeInput' => { 'activityStart' => {} })
    expect(frames.last).to eq('realtimeInput' => { 'activityEnd' => {} })
    chunks = frames[1...-1].map { |frame| Base64.strict_decode64(frame.dig('realtimeInput', 'audio', 'data')) }
    expect(chunks.map(&:bytesize)).to all(be_even)
    expect(chunks.join).to eq(sample.data)
  end

  it 'waits for setupComplete before sending any audio' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection, close: nil)
    allow(socket).to receive(:send_text)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open).and_yield(socket)
    ready = false
    allow(protocol).to receive(:send_transcription_audio) { expect(ready).to be(true) }
    allow(socket).to receive(:each_message) do |write:, &block|
      writer = Thread.new { write.call(socket) }
      ready = true
      events.each { |event| block.call(JSON.generate(event)) }
      expect(writer.join(1)).to eq(writer)
      writer.value
    ensure
      writer&.kill
    end

    protocol.collect_transcription(audio, {})

    expect(protocol).to have_received(:send_transcription_audio).once
  end

  it 'rejects unsupported metadata requests and overrides before connecting' do
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open)

    expect { RubyLLM.transcribe(path, model:, provider: :gemini, timestamps: :word) { nil } }
      .to raise_error(ArgumentError, /timestamps/)
    expect { RubyLLM.transcribe(path, model:, provider: :gemini, speaker_names: ['Speaker']) { nil } }
      .to raise_error(ArgumentError, /diarization/)
    expect do
      RubyLLM.transcribe(path, model:, provider: :gemini,
                               provider_options: { inputAudioTranscription: { wordTimestamp: true } }) { nil }
    end.to raise_error(ArgumentError, /word timestamps/)
    expect(RubyLLM::Transport::WebsocketConnection).not_to have_received(:open)
  end

  it 'rejects multiple files, stereo PCM, and incomplete sample frames before opening a socket' do
    expect { protocol.transcription_audio([path, path]) }.to raise_error(ArgumentError, /exactly one/)
    invalid = instance_double(RubyLLM::Transcription::WavAudio,
                              encoding: 1, channels: 2, bits_per_sample: 16, data: 'ab'.b)
    allow(RubyLLM::Transcription::WavAudio).to receive(:new).and_return(invalid)
    expect { protocol.transcription_audio(path) }.to raise_error(ArgumentError, /mono/)
    allow(invalid).to receive_messages(channels: 1, data: 'abc'.b)
    expect { protocol.transcription_audio(path) }.to raise_error(ArgumentError, /16-bit/)
  end

  it 'uses the Vertex Live service, project model path, and global endpoint without changing Gemini URLs' do
    vertex = RubyLLM::Providers::VertexAI.new(RubyLLM.config)
    dialect = RubyLLM::Providers::VertexAI::LiveTranscription.new(vertex)
    id = model_for(:vertexai, :live_transcription)

    expect(dialect.transcription_websocket_url)
      .to eq('wss://aiplatform.googleapis.com/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent')
    expect(dialect.transcription_model_name(id)).to eq(vertex.model_path(id))
    expect(protocol.transcription_model_name(model)).to eq("models/#{model}")
  end
end
