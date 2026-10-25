# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlankKeys do
  let(:dotenv) { Tempfile.new('env') }

  after { dotenv.close! }

  it 'treats an empty key as a missing one' do
    env = { 'DEEPGRAM_API_KEY' => '', 'HETZNER_API_KEY' => " \n", 'OPENAI_API_KEY' => 'sk-test' }

    described_class.clear(env, dotenv: dotenv.path)

    expect(env).to eq('OPENAI_API_KEY' => 'sk-test')
  end

  it 'clears any empty variable .env sets, whatever its name' do
    dotenv.write(%(GOOGLE_CLOUD_PROJECT=$(op-cache read "op://RubyLLM/Google Cloud/project")\nexport AWS_REGION=\n))
    dotenv.flush
    env = { 'GOOGLE_CLOUD_PROJECT' => '', 'AWS_REGION' => '', 'CI' => '' }

    described_class.clear(env, dotenv: dotenv.path)

    expect(env).to eq('CI' => '')
  end

  context 'when 1Password could not read a key' do
    include_context 'with configured RubyLLM'

    around do |example|
      saved = ENV.fetch('DEEPGRAM_API_KEY', nil)
      ENV['DEEPGRAM_API_KEY'] = ''
      described_class.clear(ENV, dotenv: dotenv.path)
      example.run
    ensure
      saved ? ENV['DEEPGRAM_API_KEY'] = saved : ENV.delete('DEEPGRAM_API_KEY')
    end

    it 'replays the recording instead of failing and deleting it' do
      audio = File.expand_path('fixtures/ruby.wav', __dir__)

      transcription = VCR.use_cassette('providers_deepgram_audio_transcribes_a_local_file_with_nova-3',
                                       record: :none) do
        RubyLLM.transcribe(audio, model: 'nova-3', provider: :deepgram)
      end

      expect(transcription.text).to match(/ruby/i)
    end
  end
end
