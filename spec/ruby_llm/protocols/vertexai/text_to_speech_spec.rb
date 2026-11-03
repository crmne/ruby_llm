# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::TextToSpeech do
  let(:instrumenter) { CaptureInstrumenter.new }
  let(:location) { 'eu' }
  let(:context) do
    RubyLLM.context do |config|
      config.vertexai_project_id = 'speech-project'
      config.vertexai_location = location
      config.instrumenter = instrumenter
    end
  end
  let(:provider) { RubyLLM::Providers::VertexAI.new(context.config) }

  before do |example|
    next if example.metadata[:live]

    allow(RubyLLM::Accounting::Usage).to receive(:ledger).and_return(nil)
    allow(provider).to receive(:headers).and_return('Authorization' => 'Bearer speech-test')
    allow(RubyLLM::Providers::VertexAI).to receive(:new).with(context.config).and_return(provider)
  end

  def model
    'Chirp3-HD'
  end

  def endpoint
    'https://eu-texttospeech.googleapis.com/v1/text:synthesize'
  end

  def audio
    "ID3\x04audio".b
  end

  def synthesized
    { audioContent: Base64.strict_encode64(audio) }
  end

  def speak(input = 'Ruby is a programming language.', **, &)
    context.speak(input, model:, provider: :vertexai, assume_model_exists: true, **, &)
  end

  def usage_events
    instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
  end

  describe 'live', :live do
    let(:context) do
      RubyLLM.context { |config| config.vertexai_location = 'eu' }
    end

    def skip_when_disabled(error)
      raise error unless error.message.match?(/Text-to-Speech API|texttospeech/i) && error.message.include?('disabled')

      VCR.current_cassette.new_recorded_interactions.clear
      skip 'Cloud Text-to-Speech API is disabled in the configured Google Cloud project'
    end

    it 'speaks through the EU endpoint' do
      speech = speak('Ruby is a programming language designed for developer happiness.')

      expect(speech).to have_attributes(model:, voice: 'en-US-Chirp3-HD-Charon', format: 'mp3',
                                        mime_type: 'audio/mpeg')
      expect(speech.data.bytesize).to be > 1000
    rescue RubyLLM::ForbiddenError => e
      skip_when_disabled(e)
    end

    it 'speaks in the language of the voice and the format asked for' do
      speech = speak('Ruby ist eine Programmiersprache.', voice: 'de-DE-Chirp3-HD-Leda', format: 'opus')

      expect(speech).to have_attributes(voice: 'de-DE-Chirp3-HD-Leda', format: 'opus', mime_type: 'audio/ogg')
      expect(speech.data.byteslice(0, 4)).to eq('OggS')
    rescue RubyLLM::ForbiddenError => e
      skip_when_disabled(e)
    end

    it 'raises a bad request error for a voice that does not exist' do
      expect { speak('Hello', voice: 'en-US-Chirp3-HD-Nobody') }.to raise_error(RubyLLM::BadRequestError)
    rescue RubyLLM::ForbiddenError => e
      skip_when_disabled(e)
    end
  end

  it 'synthesizes at the endpoint of the configured location with the default voice' do
    request = stub_request(:post, endpoint).with do |req|
      expect(req.headers).to include('Authorization' => 'Bearer speech-test',
                                     'X-Goog-User-Project' => 'speech-project')
      expect(JSON.parse(req.body)).to eq(
        'input' => { 'text' => 'Ruby is a programming language.' },
        'voice' => { 'languageCode' => 'en-US', 'name' => 'en-US-Chirp3-HD-Charon' },
        'audioConfig' => { 'audioEncoding' => 'MP3' }
      )
    end.to_return_json(body: synthesized)

    speech = speak

    expect(speech).to have_attributes(data: audio, model:, voice: 'en-US-Chirp3-HD-Charon', format: 'mp3',
                                      mime_type: 'audio/mpeg')
    expect(request).to have_been_requested.once
  end

  it 'records the usage for the owner without counts, since Google bills characters, not tokens' do
    stub_request(:post, endpoint).to_return_json(body: synthesized)

    speech = RubyLLM.with_usage_owner('account-1') { speak('Grüße aus Köln!') }

    expect(speech.tokens.input).to be_nil
    expect(speech.cost.total).to be_nil
    expect(usage_events.sole).to include(operation: :speech, provider: 'vertexai', model:, status: :succeeded,
                                         owner: 'account-1')
    expect(usage_events.sole[:tokens].input).to be_nil
    expect(usage_events.sole[:cost].total).to be_nil
  end

  it 'takes a voice in any language and the encodings by either name' do
    { 'wav' => 'LINEAR16', 'LINEAR16' => 'LINEAR16', 'opus' => 'OGG_OPUS', 'OGG_OPUS' => 'OGG_OPUS',
      'mulaw' => 'MULAW', 'alaw' => 'ALAW', wav: 'LINEAR16' }.each do |format, encoding|
      stub_request(:post, endpoint).with(body: hash_including(
        'voice' => { 'languageCode' => 'de-DE', 'name' => 'de-DE-Chirp3-HD-Leda' },
        'audioConfig' => { 'audioEncoding' => encoding }
      )).to_return_json(body: synthesized)

      speech = speak('Hallo', voice: 'de-DE-Chirp3-HD-Leda', format:)

      expect(speech.format).to eq(RubyLLM::Protocols::VertexAI::TextToSpeech::ENCODINGS.key(encoding))
    end
  end

  it 'names a bare voice in American English and reports the audio type of each container' do
    stub_request(:post, endpoint).to_return_json(body: synthesized)

    expect(speak('Hi', voice: 'Aoede', format: 'opus'))
      .to have_attributes(voice: 'en-US-Chirp3-HD-Aoede', mime_type: 'audio/ogg')
    expect(speak('Hi', format: 'wav').mime_type).to eq('audio/wav')
    expect(speak('Hi', format: 'mulaw').mime_type).to eq('audio/wav')
  end

  it 'passes an encoding it has no name for through, as the format in lower case' do
    stub_request(:post, endpoint).with(body: hash_including('audioConfig' => { 'audioEncoding' => 'PCM' }))
                                 .to_return_json(body: synthesized)

    expect(speak('Hi', format: 'PCM')).to have_attributes(format: 'pcm', mime_type: 'audio/pcm')
  end

  it 'merges provider options into the request' do
    request = stub_request(:post, endpoint).with(body: hash_including(
      'voice' => { 'languageCode' => 'en-US', 'name' => 'en-US-Chirp3-HD-Charon' },
      'audioConfig' => { 'audioEncoding' => 'MP3', 'speakingRate' => 1.2 }
    )).to_return_json(body: synthesized)

    speak('Hi', provider_options: { 'audioConfig' => { speakingRate: 1.2 } })

    expect(request).to have_been_requested.once
  end

  {
    'text' => { input: { text: 'Other text' } },
    'voice' => { voice: { languageCode: 'en-GB' } },
    'format' => { 'audioConfig' => { 'audioEncoding' => 'LINEAR16' } }
  }.each do |argument, options|
    it "refuses provider options that would replace the #{argument} it was given" do
      expect { speak('Hi', provider_options: options) }.to raise_error(ArgumentError, /instead of provider_options/)
      expect(a_request(:post, endpoint)).not_to have_been_made
    end
  end

  {
    'global' => 'https://texttospeech.googleapis.com/v1/text:synthesize',
    'us' => 'https://us-texttospeech.googleapis.com/v1/text:synthesize',
    'europe-west4' => 'https://europe-west4-texttospeech.googleapis.com/v1/text:synthesize'
  }.each do |configured, url|
    context "with vertexai_location #{configured}" do
      let(:location) { configured }

      it 'uses the endpoint of that location' do
        request = stub_request(:post, url).to_return_json(body: synthesized)

        speak

        expect(request).to have_been_requested.once
      end
    end
  end

  it 'ignores a custom Vertex AI api base, which serves a different service' do
    context.config.vertexai_api_base = 'https://aiplatform.eu.rep.googleapis.com/v1beta1'
    request = stub_request(:post, endpoint).to_return_json(body: synthesized)

    speak

    expect(request).to have_been_requested.once
  end

  it 'keeps Gemini speech models on the Gemini protocol' do
    model = RubyLLM::Model.default('gemini-2.5-flash-tts', :vertexai)

    expect(provider.protocol_for(model, operation: :speak)).not_to eq(described_class)
  end

  {
    [400, 'INVALID_ARGUMENT', 'Voice does not exist'] => RubyLLM::BadRequestError,
    [401, 'UNAUTHENTICATED', 'Request had invalid authentication credentials'] => RubyLLM::UnauthorizedError,
    [403, 'PERMISSION_DENIED', 'Cloud Text-to-Speech API has not been used in project 123 before or it is ' \
                               'disabled'] => RubyLLM::ForbiddenError,
    [429, 'RESOURCE_EXHAUSTED', 'Quota exceeded for quota metric'] => RubyLLM::RateLimitError,
    [500, 'INTERNAL', 'Internal error'] => RubyLLM::ServerError,
    [503, 'UNAVAILABLE', 'The service is currently unavailable'] => RubyLLM::ServiceUnavailableError
  }.each do |(status, code, message), error_class|
    it "raises #{error_class} for a #{status} #{code}" do
      context.config.max_retries = 0
      stub_request(:post, endpoint).to_return_json(status:, body: { error: { code: status, message:, status: code } })

      expect { speak }.to raise_error(error_class, /#{Regexp.escape(message.split.first)}/)
      expect(usage_events.sole).to include(status: :failed)
    end
  end

  it 'records a refused request as unbilled' do
    stub_request(:post, endpoint).to_return_json(status: 400, body: { error: { code: 400, message: 'Bad voice' } })

    expect { speak }.to raise_error(RubyLLM::BadRequestError)
    expect(usage_events.sole[:tokens].input).to eq(0)
  end

  it 'raises when the response carries no audio' do
    stub_request(:post, endpoint).to_return_json(body: {})

    expect { speak }.to raise_error(RubyLLM::Error, /returned no audio/)
  end

  it 'refuses to stream, which the REST API cannot do' do
    expect { speak('Hi') { nil } }.to raise_error(RubyLLM::Error, /doesn't support streaming speech/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end
end
