# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'options a wire format cannot carry' do # rubocop:disable RSpec/DescribeClass
  let(:audio) { File.expand_path('../fixtures/ruby.wav', __dir__) }
  let(:document) { File.expand_path('../fixtures/ruby.txt', __dir__) }

  def provider(slug)
    provider_class = RubyLLM::Provider.resolve!(slug)
    config = RubyLLM::Configuration.new
    provider_class.configuration_requirements.each { |key| config.public_send(:"#{key}=", 'test') }
    config.azure_api_key = 'test'
    config.bedrock_region = 'us-east-1'
    config.bedrock_api_key = 'test'
    config.bedrock_secret_key = 'test'
    provider_class.new(config)
  end

  def model(id)
    RubyLLM::Model.default(id, 'test')
  end

  {
    anthropic: { purpose: 'a', uri: 'x://a' },
    gemini: { purpose: 'a', expires_in: 60, uri: 'x://a' },
    openrouter: { purpose: 'a', expires_in: 60, uri: 'x://a' },
    openai: { uri: 'x://a' },
    azure: { uri: 'x://a' },
    deepseek: { uri: 'x://a' },
    mistral: { uri: 'x://a' },
    xai: { uri: 'x://a' },
    elevenlabs: { purpose: 'a', expires_in: 60, uri: 'x://a' },
    cohere: { expires_in: 60, uri: 'x://a' },
    bedrock: { purpose: 'a', expires_in: 60 },
    vertexai: { purpose: 'a', expires_in: 60 }
  }.each do |slug, options|
    options.each do |name, value|
      it "raises for #{name} on a #{slug} upload" do
        extra = name == :expires_in && slug == :cohere ? { purpose: 'embed-input' } : {}

        expect { provider(slug).upload_file(document, name => value, **extra) }
          .to raise_error(ArgumentError, /upload does not accept #{name}/)
      end
    end
  end

  [
    [:cohere, 'cohere-transcribe-03-2026', { format: 'json' }],
    [:cohere, 'cohere-transcribe-03-2026', { prompt: 'a' }],
    [:cohere, 'cohere-transcribe-03-2026', { speaker_names: [] }],
    [:cohere, 'cohere-transcribe-03-2026', { speaker_references: ['a.wav'] }],
    [:deepgram, 'nova-3-general', { format: 'json' }],
    [:deepgram, 'nova-3-general', { temperature: 0.1 }],
    [:deepgram, 'nova-3-general', { speaker_references: ['a.wav'] }],
    [:elevenlabs, 'scribe_v2', { prompt: 'a' }],
    [:elevenlabs, 'scribe_v2', { speaker_references: ['a.wav'] }],
    [:gemini, 'gemini-2.5-flash', { speaker_names: ['Ana'] }],
    [:gemini, 'gemini-2.5-flash', { speaker_references: ['a.wav'] }],
    [:mistral, 'voxtral-mini-latest', { format: 'json' }],
    [:mistral, 'voxtral-mini-latest', { speaker_references: ['a.wav'] }],
    [:xai, 'grok-stt', { format: 'json' }],
    [:xai, 'grok-stt', { temperature: 0.1 }],
    [:xai, 'grok-stt', { prompt: 'a' }],
    [:xai, 'grok-stt', { speaker_references: ['a.wav'] }]
  ].each do |slug, id, options|
    it "raises for #{options.keys.first} on #{slug} transcription" do
      expect { provider(slug).transcribe(audio, model: model(id), language: nil, **options) }
        .to raise_error(ArgumentError, /transcribe does not accept #{options.keys.first}/)
    end
  end

  def stub_transcription(slug, id)
    target = provider(slug)
    allow(target.protocol_for(model(id), operation: :transcribe)).to receive(:new).and_wrap_original do |method, *args|
      method.call(*args).tap { |protocol| allow(protocol).to receive(:transcribe).and_return(:transcribed) }
    end
    target
  end

  [
    [:xai, 'grok-stt'],
    [:mistral, 'voxtral-mini-latest'],
    [:deepgram, 'nova-3-general'],
    [:vertexai, 'gemini-3.5-transcribe-preview'],
    [:gemini, 'gemini-3.5-transcribe']
  ].each do |slug, id|
    it "raises for names that have no effect on #{slug} #{id}" do
      expect { provider(slug).transcribe(audio, model: model(id), language: nil, speaker_names: ['Ana']) }
        .to raise_error(ArgumentError, /transcribe does not accept named_speakers/)
    end

    it "accepts empty speaker_names on #{slug} #{id}" do
      result = stub_transcription(slug, id).transcribe(audio, model: model(id), language: nil, speaker_names: [])

      expect(result).to eq(:transcribed)
    end
  end

  it 'keeps the speaker count from names on ElevenLabs' do
    result = stub_transcription(:elevenlabs, 'scribe_v2')
             .transcribe(audio, model: model('scribe_v2'), language: nil, speaker_names: ['Ana'])

    expect(result).to eq(:transcribed)
  end

  [
    [:openai, 'text-embedding-3-small', { task_type: 'a' }],
    [:openai, 'text-embedding-3-small', { title: 'a' }],
    [:mistral, 'mistral-embed', { task_type: 'a' }],
    [:openrouter, 'openai/text-embedding-3-small', { title: 'a' }],
    [:cohere, 'embed-v4.0', { title: 'a' }],
    [:bedrock, 'amazon.titan-embed-text-v2:0', { task_type: 'a' }],
    [:bedrock, 'amazon.titan-embed-text-v2:0', { title: 'a' }],
    [:bedrock, 'amazon.nova-2-multimodal-embeddings-v1:0', { title: 'a' }],
    [:bedrock, 'us.cohere.embed-v4:0', { title: 'a' }]
  ].each do |slug, id, options|
    it "raises for #{options.keys.first} on #{slug} #{id} embeddings" do
      expect { provider(slug).embed('a', model: model(id), dimensions: nil, **options) }
        .to raise_error(ArgumentError, /embed does not accept #{options.keys.first}/)
    end
  end

  [
    [:bedrock, 'stability.sd3-5-large-v1:0'],
    [:elevenlabs, 'gemini-3.1-flash-lite-image'],
    [:openrouter, 'google/gemini-3.1-flash-lite-image']
  ].each do |slug, id|
    it "raises for several images on #{slug}" do
      expect { provider(slug).paint('a cat', model: model(id), size: nil, count: 2) }
        .to raise_error(ArgumentError, /paint does not accept count/)
    end
  end

  it 'lets count: 1 through, because that is the one image the provider returns' do
    instance = provider(:bedrock)
    stability = model('stability.sd3-5-large-v1:0')
    protocol = RubyLLM::Protocols::InvokeModel::StabilityImages.new(instance, stability)
    allow(protocol).to receive(:paint).and_return(:image)
    allow(instance).to receive(:protocol_for)
      .and_return(class_double(RubyLLM::Protocols::InvokeModel::StabilityImages, new: protocol))

    expect(instance.paint('a cat', model: stability, size: nil, count: 1)).to eq(:image)
  end

  it 'keeps options on the protocols that carry them' do
    expect(RubyLLM::Protocols::Gemini.allocate.rejected_options(:embed)).to eq([])
    expect(RubyLLM::Protocols::ChatCompletions.allocate.rejected_options(:transcribe)).to eq([])
  end

  describe 'Gemini speech' do
    let(:protocol) { RubyLLM::Protocols::Gemini.allocate }

    it 'raises for a format other than the PCM it returns' do
      expect { protocol.render_speech_payload('hi', model: 'a', voice: nil, format: 'mp3') }
        .to raise_error(ArgumentError, /returns PCM audio/)
    end

    it 'accepts pcm' do
      expect { protocol.render_speech_payload('hi', model: 'a', voice: nil, format: 'pcm') }.not_to raise_error
    end
  end

  describe 'content_type: on upload' do
    let(:context) do
      RubyLLM.context do |config|
        config.anthropic_api_key = 'test'
        config.gemini_api_key = 'test'
      end
    end

    it 'names the multipart file part' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/files')
                .with { |req| req.body.include?('Content-Type: application/x-custom') }
                .to_return_json(body: { id: 'file_1', filename: 'ruby.txt' })

      context.upload(document, provider: :anthropic, content_type: 'application/x-custom')

      expect(request).to have_been_requested
    end

    it 'names the Gemini upload' do
      start = stub_request(:post, %r{generativelanguage\.googleapis\.com/upload/v1beta/files})
              .with(headers: { 'X-Goog-Upload-Header-Content-Type' => 'application/x-custom' })
              .to_return(status: 200, headers: { 'X-Goog-Upload-URL' => 'https://upload.example.com/1' }, body: '{}')
      stub_request(:post, 'https://upload.example.com/1')
        .to_return_json(body: { file: { name: 'files/1', state: 'ACTIVE' } })

      context.upload(document, provider: :gemini, content_type: 'application/x-custom')

      expect(start).to have_been_requested
    end
  end

  describe 'internal chat uploads' do
    it 'sends OpenRouter no purpose, which its Files API cannot carry' do
      config = RubyLLM::Configuration.new.tap { |c| c.openrouter_api_key = 'test' }
      instance = RubyLLM::Providers::OpenRouter.new(config)

      [instance.protocols[:chat_completions], instance.protocols[:responses]].each do |protocol_class|
        expect(protocol_class.new(instance).send(:provider_file_upload_options, nil)).to eq({})
      end
    end
  end
end
