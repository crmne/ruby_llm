# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Speech, :live do
  include_context 'with configured RubyLLM'

  each_model(SPEECH_MODELS) do |provider, model, model_info|
    it "#{provider}/#{model} speaks" do
      speech = RubyLLM.speak(
        'Ruby is a programming language designed for developer happiness.',
        model: model,
        provider: provider,
        assume_model_exists: true,
        voice: model_info[:voice],
        format: model_info[:format]
      )

      expect(speech.data).to be_a(String)
      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq(model)
      expect(speech.mime_type).to start_with('audio/')
    end
  end
end
