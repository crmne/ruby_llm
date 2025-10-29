# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

def save_and_verify_audio(audio)
  # Create a temp file to save to
  temp_file = Tempfile.new(['audio', '.mp3'])
  temp_path = temp_file.path
  temp_file.close

  begin
    saved_path = audio.save(temp_path)
    expect(saved_path).to eq(temp_path)
    expect(File.exist?(temp_path)).to be true

    file_size = File.size(temp_path)
    expect(file_size).to be > 1000 # Any real audio should be larger than 1KB
  ensure
    # Clean up
    File.delete(temp_path)
  end
end

RSpec.describe RubyLLM::Speech do
  include_context 'with configured RubyLLM'

  describe 'basic functionality' do
    SPEECH_MODELS.each do |config|
      provider = config[:provider]
      model = config[:model]

      it "#{provider}/#{model} can generate audio from text" do
        voice = provider == :gemini ? 'Sadachbia' : 'alloy'
        audio = RubyLLM.tts(
          'Hello, welcome!',
          model: model,
          provider: provider,
          voice: voice
        )

        expect(audio.model).to eq(model)

        save_and_verify_audio audio
      end
    end

    it 'validates model existence' do
      expect do
        RubyLLM.tts('Hello, welcome!', model: 'invalid-audio-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end
end
