# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/websocket_cassette'

RSpec.describe RubyLLM::Transcription, :live do
  include WebsocketCassette

  TEST_MODELS.fetch(:dedicated_transcription).each do |entry|
    provider = entry.fetch(:provider)

    it "transcribes audio with speaker labels and word timestamps through #{provider}" do
      result = RubyLLM.transcribe(File.expand_path('../fixtures/ruby.wav', __dir__),
                                  model: model_for(provider, :dedicated_transcription), provider:,
                                  language: 'en-US', timestamps: :word, speaker_names: ['Speaker'])

      expect(result.text).to include('Ruby', 'developer happiness')
      expect(result.words).not_to be_empty
      expect(result.words).to all(include('start' => a_kind_of(Numeric), 'end' => a_kind_of(Numeric)))
      expect(result.words.filter_map { |word| word['speaker'] }).not_to be_empty
      expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    end

    it "distinguishes two speakers through #{provider} dedicated transcription" do
      result = RubyLLM.transcribe(File.expand_path('../fixtures/google-speakers.wav', __dir__),
                                  model: model_for(provider, :dedicated_transcription), provider:,
                                  timestamps: :word, speaker_names: [])

      expect(result.text).to match(/workshop.*thank you/im)
      expect(result.words.filter_map { |word| word['speaker'] }.uniq.size).to eq(2)
      expect(result.words).to all(include('start' => a_kind_of(Numeric), 'end' => a_kind_of(Numeric)))
    end
  end

  TEST_MODELS.fetch(:live_transcription).each do |entry|
    provider = entry.fetch(:provider)

    it "streams partial and final transcription through #{provider} Live" do
      key = provider == :vertexai ? 'GOOGLE_CLOUD_PROJECT' : 'GEMINI_API_KEY'
      with_websocket_cassette("transcription_google_#{provider}", key:) do
        chunks = []
        result = RubyLLM.transcribe(File.expand_path('../fixtures/ruby.wav', __dir__),
                                    model: model_for(provider, :live_transcription), provider:,
                                    language: 'en-US') { |chunk| chunks << chunk }

        expect(result.text).to include('Ruby', 'developer happiness')
        expect(result.duration).to be > 3
        expect(chunks).to include(have_attributes(partial?: true))
        expect(chunks.filter_map(&:delta).join).to eq(result.text)
        expect(chunks.last).to have_attributes(done?: true, text: result.text)
        expect(result.words).to be_nil
        expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
      end
    end
  end
end
