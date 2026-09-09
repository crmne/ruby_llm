# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription, :live do
  TEST_MODELS.fetch(:timestamp_transcription).each do |entry|
    provider = entry.fetch(:provider)
    it "requests word timestamps through #{provider} with the shared keyword" do
      result = RubyLLM.transcribe(File.expand_path('../fixtures/ruby.wav', __dir__),
                                  model: model_for(provider, :timestamp_transcription), provider:, timestamps: :word)

      expect(result.text).to match(/ruby/i)
      expect(result.words).not_to be_empty
      expect(result.words).to all(include('start' => a_kind_of(Numeric), 'end' => a_kind_of(Numeric)))
      expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    end
  end
end
