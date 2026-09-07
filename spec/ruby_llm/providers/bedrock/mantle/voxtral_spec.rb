# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Mantle::Voxtral do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.bedrock_region = 'us-west-2'
    config.bedrock_api_key = 'test'
    config.bedrock_secret_key = 'test'
    RubyLLM::Providers::Bedrock.new(config)
  end
  let(:model) { RubyLLM.models.find(model_for(:bedrock, :bedrock_transcription), provider: :bedrock) }
  let(:protocol) { described_class.new(provider, model) }
  let(:audio_path) { File.expand_path('../../../../fixtures/ruby.wav', __dir__) }

  def render(**options)
    protocol.send(:render_transcription_payload, audio_path, model: model.id, language: nil, prompt: nil,
                                                             temperature: nil, provider_options: {}, **options)
  end

  it 'routes transcription through the Voxtral dialect while preserving conversation routing' do
    expect(provider.protocol_for(model, operation: :transcribe)).to eq(described_class)
    expect(provider.protocol_for(model, operation: :complete)).to eq(provider.protocols[:mantle_chat_completions])
  end

  it 'renders audio before the transcription instructions with language and vocabulary hints' do
    payload = render(language: 'en', prompt: 'The speaker discusses Ruby.', temperature: 0.3,
                     provider_options: { max_tokens: 200 })
    parts = payload.dig(:messages, 0, :content)

    expect(payload).to include(model: model.id, temperature: 0.3, max_tokens: 200)
    expect(parts.first).to eq(type: 'input_audio',
                              input_audio: { data: RubyLLM::Attachment.new(audio_path).encoded, format: 'wav' })
    expect(parts.last[:text]).to include('Transcribe the audio verbatim.', 'audio language is en', 'discusses Ruby')
  end

  it 'rejects non-audio inputs' do
    image_path = File.expand_path('../../../../fixtures/ruby.png', __dir__)

    expect do
      protocol.send(:render_transcription_payload, image_path, model: model.id, language: nil, prompt: nil,
                                                               temperature: nil, provider_options: {})
    end.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'rejects multiple files instead of dropping later inputs' do
    expect { protocol.transcribe([audio_path, audio_path], model: model.id, language: nil) }
      .to raise_error(ArgumentError, /exactly one audio file/)
  end

  it 'returns typed transcript text and token usage' do
    response = instance_double(Faraday::Response, body: {
                                 'choices' => [{ 'message' => { 'content' => 'Ruby is a programming language.' } }],
                                 'model' => model.id, 'usage' => { 'prompt_tokens' => 386, 'completion_tokens' => 11 }
                               })

    result = protocol.send(:parse_transcription_response, response, model: model.id)

    expect(result).to be_a(RubyLLM::Transcription)
    expect(result).to have_attributes(text: 'Ruby is a programming language.', model: model.id, segments: nil)
    expect(result.tokens).to have_attributes(input: 386, output: 11)
  end

  it 'rejects missing transcript output' do
    response = instance_double(Faraday::Response, body: { 'choices' => [] })

    expect { protocol.send(:parse_transcription_response, response, model: model.id) }
      .to raise_error(RubyLLM::Error, /no transcript/) { |error| expect(error.response).to eq(response) }
  end

  it 'rejects unsupported transcript formats or speaker metadata before reading audio' do
    expect { protocol.transcribe('missing.wav', model: model.id, language: nil, format: 'diarized_json') }
      .to raise_error(ArgumentError, /plain text/)
    expect { protocol.transcribe('missing.wav', model: model.id, language: nil, speaker_names: ['Alice']) }
      .to raise_error(ArgumentError, /speaker labels/)
    expect { protocol.render_transcription_options(timestamps: :word) }
      .to raise_error(ArgumentError, /does not return timestamps/)
  end

  it 'signs the Mantle transcription request and records its usage' do
    response = instance_double(Faraday::Response, body: {
                                 'choices' => [{ 'message' => { 'content' => 'Ruby is a programming language.' } }],
                                 'usage' => { 'prompt_tokens' => 386, 'completion_tokens' => 11 }
                               })
    request = Struct.new(:headers).new({})
    allow(provider).to receive(:sign_headers).and_return('Authorization' => 'signed')
    allow(provider.mantle_connection).to receive(:post).and_yield(request).and_return(response)

    result = protocol.transcribe(audio_path, model: model.id, language: nil)

    expect(provider).to have_received(:sign_headers).with('POST', 'v1/chat/completions', JSON.generate(render),
                                                          base_url: provider.mantle_api_base, service: 'bedrock-mantle')
    expect(request.headers).to include('Authorization' => 'signed')
    expect(result.tokens).to have_attributes(input: 386, output: 11)
  end

  it 'transcribes speech through Bedrock Voxtral with typed usage', :live do
    result = RubyLLM.transcribe(audio_path, model: model_for(:bedrock, :bedrock_transcription), provider: :bedrock)

    expect(result.text).to match(/Ruby is a programming language designed for developer happiness/i)
    expect(result.model).to eq(model_for(:bedrock, :bedrock_transcription))
    expect(result.tokens.input).to be_positive
    expect(result.tokens.output).to be_positive
  end

  it 'streams a complete multi-utterance WAV transcript through Bedrock Voxtral with typed usage', :live do
    chunks = []
    meeting = File.expand_path('../../../../fixtures/google-speakers.wav', __dir__)
    result = RubyLLM.transcribe(meeting, model: model_for(:bedrock, :bedrock_transcription),
                                         provider: :bedrock) do |chunk|
      chunks << chunk
    end

    expect(result.text).to match(/workshop begins at (nine|9)/i)
    expect(result.text).to match(/arrive early.*ruby examples/i)
    expect(chunks.count(&:delta?)).to be_positive
    expect(chunks.filter_map(&:delta).join).to eq(result.text)
    expect(chunks.last).to have_attributes(done?: true, text: result.text)
    expect(result.model).to eq(model_for(:bedrock, :bedrock_transcription))
    expect(result.tokens.input).to be_positive
    expect(result.tokens.output).to be_positive
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
  end
end
