# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Deepgram::StreamingTranscription do
  let(:protocol) { Object.new.extend(described_class) }

  it 'separates revisable partials from timed committed segments and word speakers' do
    event = { 'type' => 'Results', 'start' => 1.2, 'duration' => 0.8, 'channel_index' => [0, 1],
              'channel' => { 'alternatives' => [{ 'transcript' => 'Hello Ruby.',
                                                  'words' => [{ 'word' => 'hello', 'speaker' => 0 }] }] } }
    segments = []
    chunks = []
    protocol.process_transcription_result(event, segments) { |chunk| chunks << chunk }
    expect(segments).to be_empty

    protocol.process_transcription_result(event.merge('is_final' => true), segments) { |chunk| chunks << chunk }

    expect(chunks.first).to have_attributes(partial?: true, text: 'Hello Ruby.', delta: nil)
    expect(chunks.last).to have_attributes(segment?: true, delta: 'Hello Ruby.')
    expect(segments.first).to include('start' => 1.2, 'end' => 2.0, 'channel' => 0)
    expect(segments.first.fetch('words').first).to include('speaker' => 0)
  end

  it 'sends all audio bytes before requesting the final transcript and connection close' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    bytes = []
    allow(socket).to receive(:send_binary) { |data| bytes << data }
    allow(socket).to receive(:send_text) do
      expect(bytes.join).to eq('a'.b * 20_000)
    end

    protocol.send_transcription_audio(socket, 'a'.b * 20_000)

    expect(socket).to have_received(:send_text).with(JSON.generate(type: 'CloseStream')).once
  end
end
