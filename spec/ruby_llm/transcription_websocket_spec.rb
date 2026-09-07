# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/websocket_cassette'

RSpec.describe RubyLLM::Transcription, :live do
  include WebsocketCassette

  TEST_MODELS.fetch(:websocket_transcription).each do |entry|
    provider = entry.fetch(:provider)

    it "streams transcription through #{provider} WebSockets" do
      with_websocket_cassette("transcription_#{provider}", key: "#{provider.to_s.upcase}_API_KEY") do
        chunks = []
        result = RubyLLM.transcribe(File.expand_path('../fixtures/ruby.wav', __dir__),
                                    model: model_for(provider, :websocket_transcription), provider:,
                                    assume_model_exists: entry.fetch(:assume_model_exists, false)) do |chunk|
          chunks << chunk
        end

        expect(result.text).to include('Ruby', 'developer happiness')
        expect(result.duration).to be > 3
        expect(chunks).to include(have_attributes(partial?: true))
        expect(chunks.filter_map(&:delta).join).to eq(result.text)
        expect(chunks.last).to have_attributes(done?: true, text: result.text)
        expect(result.words).not_to be_empty
        expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
      end
    end
  end
end
