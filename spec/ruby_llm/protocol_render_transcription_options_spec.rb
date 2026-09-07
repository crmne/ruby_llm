# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol, '#render_transcription_options' do
  include_context 'with configured RubyLLM'

  let(:openai) { RubyLLM::Protocols::ChatCompletions.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config)) }
  let(:elevenlabs) { RubyLLM::Protocols::ElevenLabs.new(RubyLLM::Providers::ElevenLabs.new(RubyLLM.config)) }

  it 'requests word and segment timestamps with the required verbose OpenAI response format' do
    expect(openai.render_transcription_options(timestamps: %i[word segment], format: nil, streaming: false))
      .to eq(response_format: 'verbose_json', timestamp_granularities: %w[word segment])
  end

  it 'does not change the existing format when timestamps are omitted' do
    expect(openai.render_transcription_options(timestamps: nil, format: 'diarized_json', streaming: true)).to eq({})
    expect(elevenlabs.render_transcription_options(timestamps: nil, format: 'character', streaming: false)).to eq({})
  end

  it 'rejects incompatible OpenAI formats, streaming, and unknown granularities' do
    expect { openai.render_transcription_options(timestamps: :word, format: 'text', streaming: false) }
      .to raise_error(ArgumentError, /verbose_json/)
    expect { openai.render_transcription_options(timestamps: :word, format: nil, streaming: true) }
      .to raise_error(ArgumentError, /non-streaming/)
    expect { openai.render_transcription_options(timestamps: :character, format: nil, streaming: false) }
      .to raise_error(ArgumentError, /word or segment/)
  end

  it 'maps ElevenLabs character timestamps and rejects an inconsistent legacy format' do
    expect(elevenlabs.render_transcription_options(timestamps: :character, format: nil, streaming: false))
      .to eq(timestamps_granularity: 'character')
    expect { elevenlabs.render_transcription_options(timestamps: :word, format: 'character', streaming: false) }
      .to raise_error(ArgumentError, /match format/)
  end

  it 'enables realtime word timestamps without sending the buffered endpoint parameter' do
    expect(elevenlabs.render_transcription_options(timestamps: :word, format: nil, streaming: true))
      .to eq(include_timestamps: true)
    expect { elevenlabs.render_transcription_options(timestamps: :character, format: nil, streaming: true) }
      .to raise_error(ArgumentError, /must be word/)
  end

  it 'rejects timestamps on a protocol without a mapping instead of silently discarding the option' do
    protocol = described_class.new(RubyLLM::Providers::Gemini.new(RubyLLM.config))

    expect(protocol.render_transcription_options(timestamps: nil)).to eq({})
    expect { protocol.render_transcription_options(timestamps: :word) }
      .to raise_error(ArgumentError, /does not support timestamps/)
  end

  it 'does not apply OpenAI response formats to xAI or Mistral timestamp requests' do
    xai = RubyLLM::Providers::XAI::ChatCompletions.new(RubyLLM::Providers::XAI.new(RubyLLM.config))
    mistral = RubyLLM::Providers::Mistral::ChatCompletions.new(RubyLLM::Providers::Mistral.new(RubyLLM.config))

    expect(xai.render_transcription_options(timestamps: :word, streaming: true)).to eq({})
    expect { xai.render_transcription_options(timestamps: :segment) }.to raise_error(ArgumentError, /must be word/)
    expect(mistral.render_transcription_options(timestamps: :segment, streaming: true))
      .to eq(timestamp_granularities: ['segment'])
    expect { mistral.render_transcription_options(timestamps: :word) }.to raise_error(ArgumentError, /must be segment/)
  end

  it 'accepts the word timestamps already returned by Deepgram' do
    deepgram = RubyLLM::Protocols::Deepgram.new(RubyLLM::Providers::Deepgram.new(RubyLLM.config))

    expect(deepgram.render_transcription_options(timestamps: :word)).to eq({})
    expect do
      deepgram.render_transcription_options(timestamps: :character)
    end.to raise_error(ArgumentError, /must be word/)
  end

  it 'forwards the public timestamp option into the selected protocol request' do
    request = stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions').with do |req|
      req.body.include?('verbose_json') && req.body.include?('timestamp_granularities')
    end.to_return(body: JSON.generate(text: 'Hello', words: [{ word: 'Hello', start: 0, end: 1 }]),
                  headers: { 'Content-Type' => 'application/json' })

    result = RubyLLM.transcribe(File.expand_path('../fixtures/ruby.wav', __dir__),
                                model: model_for(:openai, :timestamp_transcription), provider: :openai,
                                timestamps: :word)

    expect(request).to have_been_requested.once
    expect(result.words.first).to include('word' => 'Hello', 'start' => 0, 'end' => 1)
  end
end
