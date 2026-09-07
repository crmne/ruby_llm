# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Speech do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:mistral, :speech) }

  def speech_events(*events)
    events.map { |event| "event: #{event.fetch(:type)}\ndata: #{JSON.generate(event)}\n\n" }.join
  end

  describe '#stream_speech' do
    let(:delta) { { type: 'speech.audio.delta', audio_data: Base64.strict_encode64("\xFFaudio".b) } }
    let(:done) { { type: 'speech.audio.done', usage: { prompt_tokens: 4, completion_tokens: 16 } } }

    it 'decodes audio events and retains completion usage' do
      request = stub_request(:post, 'https://api.mistral.ai/v1/audio/speech')
                .with(body: { input: 'Hello', model:, voice_id: 'en_paul_neutral', stream: true })
                .to_return(body: speech_events(delta, delta, done), headers: { 'content-type' => 'text/event-stream' })
      chunks = []

      speech = RubyLLM.speak('Hello', model:, provider: :mistral, voice: 'en_paul_neutral') do |chunk|
        chunks << chunk
      end

      expect(request).to have_been_requested.once
      expect(chunks.map(&:data)).to eq(["\xFFaudio".b, "\xFFaudio".b])
      expect(speech.data).to eq(chunks.map(&:data).join)
      expect(speech.tokens.to_h).to eq(input_tokens: 4, output_tokens: 16)
      expect(speech.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    end

    it 'rejects an audio stream that ends before completion' do
      stub_request(:post, 'https://api.mistral.ai/v1/audio/speech')
        .to_return(body: speech_events(delta), headers: { 'content-type' => 'text/event-stream' })

      expect { RubyLLM.speak('Hello', model:, provider: :mistral) { |_chunk| nil } }
        .to raise_error(RubyLLM::Error, /before its completion event/)
    end

    it 'raises streaming provider errors without delivering them as speech' do
      stub_request(:post, 'https://api.mistral.ai/v1/audio/speech')
        .to_return(body: "event: error\ndata: {\"error\":{\"message\":\"Generation failed\"}}\n\n",
                   headers: { 'content-type' => 'text/event-stream' })
      chunks = []

      expect { RubyLLM.speak('Hello', model:, provider: :mistral) { |chunk| chunks << chunk } }
        .to raise_error(RubyLLM::Error, /Generation failed/)
      expect(chunks).to be_empty
    end
  end

  describe '.render_speech_payload' do
    it 'passes the voice through without an OpenAI-style default' do
      payload = described_class.render_speech_payload('Hello', model: 'voxtral-mini-tts-latest',
                                                               voice: 'en_paul_neutral', format: nil)

      expect(payload).to eq(model: 'voxtral-mini-tts-latest', input: 'Hello', voice_id: 'en_paul_neutral')
    end
  end

  describe '.parse_speech_response' do
    it 'decodes base64 audio_data from the JSON body' do
      response = instance_double(Faraday::Response, body: { 'audio_data' => Base64.strict_encode64('audio bytes') })

      speech = described_class.parse_speech_response(response, model: 'voxtral-mini-tts-latest',
                                                               voice: 'en_paul_neutral', format: nil)

      expect(speech.data).to eq('audio bytes')
      expect(speech.format).to eq('mp3')
      expect(speech.voice).to eq('en_paul_neutral')
    end
  end
end
