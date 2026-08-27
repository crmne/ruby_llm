# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider do
  def api_base_cases
    {
      anthropic: {
        provider: RubyLLM::Providers::Anthropic,
        key: :anthropic_api_base,
        custom: 'https://anthropic-proxy.example.com',
        default: 'https://api.anthropic.com'
      },
      azure: {
        provider: RubyLLM::Providers::Azure,
        key: :azure_api_base,
        custom: 'https://azure-resource.example.com'
      },
      bedrock: {
        provider: RubyLLM::Providers::Bedrock,
        key: :bedrock_api_base,
        custom: 'https://bedrock-proxy.example.com',
        default: 'https://bedrock-runtime.us-east-1.amazonaws.com'
      },
      cohere: {
        provider: RubyLLM::Providers::Cohere,
        key: :cohere_api_base,
        custom: 'https://cohere-proxy.example.com',
        default: 'https://api.cohere.com'
      },
      deepgram: {
        provider: RubyLLM::Providers::Deepgram,
        key: :deepgram_api_base,
        custom: 'https://deepgram-proxy.example.com',
        default: 'https://api.deepgram.com'
      },
      deepseek: {
        provider: RubyLLM::Providers::DeepSeek,
        key: :deepseek_api_base,
        custom: 'https://deepseek-proxy.example.com',
        default: 'https://api.deepseek.com'
      },
      elevenlabs: {
        provider: RubyLLM::Providers::ElevenLabs,
        key: :elevenlabs_api_base,
        custom: 'https://api.eu.residency.elevenlabs.io',
        default: 'https://api.elevenlabs.io'
      },
      gemini: {
        provider: RubyLLM::Providers::Gemini,
        key: :gemini_api_base,
        custom: 'https://gemini-proxy.example.com/v1',
        default: 'https://generativelanguage.googleapis.com/v1beta'
      },
      gpustack: {
        provider: RubyLLM::Providers::GPUStack,
        key: :gpustack_api_base,
        custom: 'https://gpustack.example.com/v1'
      },
      mistral: {
        provider: RubyLLM::Providers::Mistral,
        key: :mistral_api_base,
        custom: 'https://mistral-proxy.example.com/v1',
        default: 'https://api.mistral.ai/v1'
      },
      ollama: {
        provider: RubyLLM::Providers::Ollama,
        key: :ollama_api_base,
        custom: 'https://ollama.example.com/v1'
      },
      ollama_cloud: {
        provider: RubyLLM::Providers::OllamaCloud,
        key: :ollama_cloud_api_base,
        custom: 'https://ollama-proxy.example.com/v1',
        default: 'https://ollama.com/v1'
      },
      openai: {
        provider: RubyLLM::Providers::OpenAI,
        key: :openai_api_base,
        custom: 'https://openai-proxy.example.com/v1',
        default: 'https://api.openai.com/v1'
      },
      openrouter: {
        provider: RubyLLM::Providers::OpenRouter,
        key: :openrouter_api_base,
        custom: 'https://openrouter-proxy.example.com/api/v1',
        default: 'https://openrouter.ai/api/v1'
      },
      perplexity: {
        provider: RubyLLM::Providers::Perplexity,
        key: :perplexity_api_base,
        custom: 'https://perplexity-proxy.example.com',
        default: 'https://api.perplexity.ai'
      },
      vertexai: {
        provider: RubyLLM::Providers::VertexAI,
        key: :vertexai_api_base,
        custom: 'https://vertex-proxy.example.com/v1beta1',
        default: 'https://us-east1-aiplatform.googleapis.com/v1beta1'
      },
      xai: {
        provider: RubyLLM::Providers::XAI,
        key: :xai_api_base,
        custom: 'https://xai-proxy.example.com/v1',
        default: 'https://api.x.ai/v1'
      }
    }
  end

  def config_for(slug)
    RubyLLM::Configuration.new.tap do |config|
      case slug
      when :anthropic
        config.anthropic_api_key = 'anthropic-key'
      when :azure
        config.azure_api_base = 'https://azure-resource.example.com'
        config.azure_api_key = 'azure-key'
      when :bedrock
        config.bedrock_api_key = 'bedrock-key'
        config.bedrock_secret_key = 'bedrock-secret'
        config.bedrock_region = 'us-east-1'
      when :cohere
        config.cohere_api_key = 'cohere-key'
      when :deepgram
        config.deepgram_api_key = 'deepgram-key'
      when :deepseek
        config.deepseek_api_key = 'deepseek-key'
      when :elevenlabs
        config.elevenlabs_api_key = 'elevenlabs-key'
      when :gemini
        config.gemini_api_key = 'gemini-key'
      when :gpustack
        config.gpustack_api_base = 'https://gpustack.example.com/v1'
        config.gpustack_api_key = 'gpustack-key'
      when :mistral
        config.mistral_api_key = 'mistral-key'
      when :ollama
        config.ollama_api_base = 'https://ollama.example.com/v1'
        config.ollama_api_key = 'ollama-key'
      when :ollama_cloud
        config.ollama_cloud_api_key = 'ollama-cloud-key'
      when :openai
        config.openai_api_key = 'openai-key'
      when :openrouter
        config.openrouter_api_key = 'openrouter-key'
      when :perplexity
        config.perplexity_api_key = 'perplexity-key'
      when :vertexai
        config.vertexai_project_id = 'vertex-project'
        config.vertexai_location = 'us-east1'
      when :xai
        config.xai_api_key = 'xai-key'
      end
    end
  end

  describe '#parse_error' do
    it 'returns nil for empty error bodies on every provider' do
      described_class.providers.each do |slug, provider_class|
        provider = provider_class.new(config_for(slug))

        [nil, '', {}, []].each do |body|
          response = instance_double(Faraday::Response, body: body)

          expect(provider.parse_error(response)).to be_nil
        end
      end
    end
  end

  describe '.register' do
    it 'registers provider configuration options on Configuration' do
      provider_key = :test_provider_spec
      option_keys = %i[test_provider_api_key test_provider_api_base]

      provider_class = Class.new(described_class) do
        class << self
          def configuration_options
            %i[test_provider_api_key test_provider_api_base]
          end

          def configuration_requirements
            %i[test_provider_api_key]
          end
        end
      end

      original_providers = described_class.providers.dup

      begin
        described_class.register(provider_key, provider_class)

        config = RubyLLM::Configuration.new
        option_keys.each do |key|
          expect(config).to respond_to(key)
          expect(config).to respond_to("#{key}=")
        end
      ensure
        described_class.providers.replace(original_providers)
        option_keys.each do |key|
          RubyLLM::Configuration.send(:option_keys).delete(key)
          RubyLLM::Configuration.send(:defaults).delete(key)
          RubyLLM::Configuration.class_eval do
            remove_method key if method_defined?(key)
            remove_method :"#{key}=" if method_defined?(:"#{key}=")
          end
        end
      end
    end

    it 'registers a provider gem model catalog' do
      provider_key = :openai
      provider_class = described_class.resolve!(provider_key)
      original_providers = described_class.providers.dup
      original_files = described_class.model_registry_files.dup

      begin
        described_class.register(provider_key, provider_class, models: '/tmp/openai-models.json')

        expect(described_class.model_registry_files).to include(
          provider_key => '/tmp/openai-models.json'
        )
      ensure
        described_class.providers.replace(original_providers)
        described_class.model_registry_files.replace(original_files)
      end
    end
  end

  describe '.configured?' do
    it 'treats blank required configuration as missing' do
      provider_class = Class.new(described_class) do
        class << self
          def configuration_options
            %i[blank_test_api_key]
          end

          def configuration_requirements
            %i[blank_test_api_key]
          end
        end
      end

      RubyLLM::Configuration.register_provider_options(provider_class.configuration_options)
      config = RubyLLM::Configuration.new
      config.blank_test_api_key = ''

      expect(provider_class.configured?(config)).to be(false)
    ensure
      RubyLLM::Configuration.send(:option_keys).delete(:blank_test_api_key)
      RubyLLM::Configuration.send(:defaults).delete(:blank_test_api_key)
      RubyLLM::Configuration.class_eval do
        remove_method :blank_test_api_key if method_defined?(:blank_test_api_key)
        remove_method :blank_test_api_key= if method_defined?(:blank_test_api_key=)
      end
    end
  end

  describe 'provider configuration schema' do
    it 'keeps requirements as a subset of declared configuration options' do
      described_class.providers.each_value do |provider_class|
        missing = provider_class.configuration_requirements - provider_class.configuration_options
        expect(missing).to be_empty,
                           "#{provider_class.display_name} is missing options for requirements: #{missing.inspect}"
      end
    end

    it 'exposes aggregated provider options through Configuration' do
      expect(RubyLLM::Configuration.options).to include(
        :openrouter_api_base,
        :deepseek_api_base,
        :ollama_api_key
      )

      expect(RubyLLM::Configuration.options).to include(
        :request_timeout,
        :model_registry_store
      )
    end
  end

  context 'with API base configuration' do
    it 'covers every registered provider' do
      expect(api_base_cases.keys).to match_array(described_class.providers.keys)
    end

    it 'registers an API base option for every provider' do
      expected_options = api_base_cases.values.map { |data| data[:key] }

      expect(RubyLLM::Configuration.options).to include(*expected_options)
    end

    it 'uses the configured API base for every provider' do
      api_base_cases.each do |slug, data|
        config = config_for(slug)
        config.public_send("#{data[:key]}=", data[:custom])

        expect(data[:provider].new(config).api_base).to eq(data[:custom])
      end
    end

    it 'keeps existing defaults for providers with built-in endpoints' do
      api_base_cases.each do |slug, data|
        next unless data[:default]

        expect(data[:provider].new(config_for(slug)).api_base).to eq(data[:default])
      end
    end
  end

  describe 'protocol resolution' do
    let(:provider) { RubyLLM::Providers::OpenAI.new(config_for(:openai)) }
    let(:model) { instance_double(RubyLLM::Model, id: 'gpt-5.4') }

    it 'defaults to the first declared protocol' do
      expect(RubyLLM::Providers::OpenAI.default_protocol).to eq(:responses)
      expect(RubyLLM::Providers::Mistral.default_protocol).to eq(:chat_completions)
    end

    it 'routes through protocol_for by default' do
      expect(provider.send(:resolve_protocol, nil, model)).to eq(provider.protocols[:responses])
    end

    it 'routes chat-completions-only models away from the default' do
      audio = instance_double(RubyLLM::Model, id: 'gpt-audio-mini')

      expect(provider.send(:resolve_protocol, nil, audio)).to eq(provider.protocols[:chat_completions])
    end

    it 'prefers the configured protocol over routing' do
      config = config_for(:openai)
      config.openai_protocol = :chat_completions

      provider = RubyLLM::Providers::OpenAI.new(config)

      expect(provider.send(:resolve_protocol, nil, model)).to eq(provider.protocols[:chat_completions])
    end

    it 'prefers an explicit protocol over the configured one' do
      config = config_for(:openai)
      config.openai_protocol = :chat_completions

      provider = RubyLLM::Providers::OpenAI.new(config)

      expect(provider.send(:resolve_protocol, :responses, model)).to eq(provider.protocols[:responses])
    end

    it 'lists models through the declared protocol whatever the chat protocol is' do
      config = config_for(:vertexai)
      config.vertexai_protocol = :anthropic

      provider = RubyLLM::Providers::VertexAI.new(config)

      expect(provider.send(:default_protocol)).to eq(provider.protocols[:anthropic])
      expect(provider.send(:listing_protocol)).to eq(provider.protocols[:gemini])
    end

    it 'routes one-shot APIs through protocol_for' do
      routed_model = instance_double(RubyLLM::Model, id: 'gpt-audio-mini')
      protocol = instance_double(
        RubyLLM::Protocols::ChatCompletions,
        embed: RubyLLM::Embedding.new(vectors: [0.1], model: routed_model.id),
        moderate: RubyLLM::Moderation.new(id: 'modr_1', model: routed_model.id, results: []),
        paint: RubyLLM::Image.new(model: routed_model.id),
        speak: RubyLLM::Speech.new(data: 'audio', model: routed_model.id),
        transcribe: RubyLLM::Transcription.new(text: 'transcript', model: routed_model.id)
      )

      allow(RubyLLM::Protocols::ChatCompletions).to receive(:new)
        .with(provider, routed_model)
        .and_return(protocol)

      provider.embed('hello', model: routed_model, dimensions: nil)
      provider.moderate('hello', model: routed_model)
      provider.paint('hello', model: routed_model, size: '1024x1024')
      provider.speak('hello', model: routed_model, voice: nil, format: nil)
      provider.transcribe('audio.mp3', model: routed_model, language: nil)

      expect(RubyLLM::Protocols::ChatCompletions).to have_received(:new)
        .with(provider, routed_model)
        .exactly(5).times
      expect(protocol).to have_received(:embed)
        .with('hello', model: routed_model.id, dimensions: nil, task_type: nil, title: nil, with: nil,
                       provider_options: {})
      expect(protocol).to have_received(:moderate).with('hello', model: routed_model.id, with: [],
                                                                 provider_options: {})
      expect(protocol).to have_received(:paint).with(
        'hello',
        model: routed_model.id,
        size: '1024x1024',
        count: nil,
        with: nil,
        mask: nil,
        provider_options: {}
      )
      expect(protocol).to have_received(:speak).with(
        'hello',
        model: routed_model.id,
        voice: nil,
        format: nil,
        provider_options: {}
      )
      expect(protocol).to have_received(:transcribe).with(
        'audio.mp3',
        model: routed_model.id,
        language: nil,
        provider_options: {},
        prompt: nil,
        temperature: nil,
        format: nil,
        speaker_names: nil,
        speaker_references: nil
      )
    end

    it 'raises on protocols the provider does not speak' do
      expect do
        provider.send(:resolve_protocol, :gemini, model)
      end.to raise_error(RubyLLM::Error, /gemini is not a protocol of OpenAI\. Available: responses, chat_completions/)
    end

    it 'uses Responses as the default batch protocol' do
      config = config_for(:openai)
      config.openai_protocol = :chat_completions

      provider = RubyLLM::Providers::OpenAI.new(config)

      expect(provider.send(:batch_protocol)).to be < RubyLLM::Protocols::Responses
      expect(provider.send(:batch_protocol)).to be_public_method_defined(:create_batch)
    end

    it 'routes OpenAI batches by rendered payload shape' do
      expect(provider.send(:batch_protocol_for, [{ payload: { input: [{ role: 'user', content: 'hi' }] } }]))
        .to be < RubyLLM::Protocols::Responses
      expect(provider.send(:batch_protocol_for, [{ payload: { messages: [] } }]))
        .to be < RubyLLM::Protocols::ChatCompletions
      expect(provider.send(:batch_protocol_for, [{ payload: { model: 'text-embedding-3-small', input: 'hi' } }]))
        .to be < RubyLLM::Protocols::ChatCompletions::EmbeddingBatches
      expect do
        provider.send(:batch_protocol_for, [
                        { payload: { input: [{ role: 'user', content: 'hi' }] } },
                        { payload: { messages: [] } }
                      ])
      end.to raise_error(RubyLLM::Error, /one endpoint/)
    end
  end

  describe 'files protocol registration' do
    it 'exposes provider-managed files only where implemented' do
      file_providers = %i[anthropic azure bedrock gemini mistral openai openrouter vertexai xai]

      described_class.providers.each do |slug, provider_class|
        provider = provider_class.new(config_for(slug))
        expect(provider.files?).to eq(file_providers.include?(slug))
        expect(provider.protocols[:files]).to be < RubyLLM::Protocols::Files if provider.files?
      end
    end
  end

  describe 'base implementations' do
    let(:bare_provider) do
      Class.new(described_class) do
        def self.slug = 'bare'
        def self.configured?(_config) = true

        def api_base = 'https://bare.example.test'
      end.new(RubyLLM::Configuration.new)
    end

    it 'requires subclasses to name an API base' do
      expect { Class.new(described_class).allocate.api_base }.to raise_error(NotImplementedError)
    end

    it 'sends no headers by default' do
      expect(bare_provider.headers).to eq({})
    end

    it 'reports no capability augmenter and no configuration requirements' do
      expect(bare_provider.capabilities).to be_nil
      expect(bare_provider.configuration_requirements).to eq([])
      expect(described_class.configuration_options).to eq([])
    end

    it 'is remote and does not assume models exist' do
      expect(bare_provider).not_to be_local
      expect(bare_provider).not_to be_assume_models_exist
      expect(bare_provider).to be_configured
    end

    it 'names itself from the class' do
      expect(RubyLLM::Providers::OpenAI.new(config_for(:openai)).name).to eq('OpenAI')
      expect(RubyLLM::Providers::OpenAI.new(config_for(:openai)).slug).to eq('openai')
    end
  end

  describe 'providers without file support' do
    let(:provider) { RubyLLM::Providers::DeepSeek.new(config_for(:deepseek)) }

    it 'refuses every file operation' do
      expect { provider.upload_file('file.txt') }.to raise_error(RubyLLM::Error, /doesn't support file uploads/)
      expect { provider.find_file('id') }.to raise_error(RubyLLM::Error, /doesn't support file uploads/)
      expect { provider.download_file('id') }.to raise_error(RubyLLM::Error, /doesn't support file uploads/)
      expect { provider.list_file_uris('uri') }.to raise_error(RubyLLM::Error, /doesn't support file uploads/)
    end
  end

  describe '#parse_error body shapes' do
    let(:provider) { RubyLLM::Providers::OpenAI.new(config_for(:openai)) }

    def response_for(body)
      Struct.new(:body).new(body)
    end

    it 'is nil for a body with nothing in it' do
      expect(provider.parse_error(response_for(nil))).to be_nil
      expect(provider.parse_error(response_for(''))).to be_nil
    end

    it 'reads a string error field' do
      expect(provider.parse_error(response_for({ 'error' => 'flat error' }))).to eq('flat error')
    end

    it 'reads the first string among the usual message fields' do
      expect(provider.parse_error(response_for({ 'error' => { 'message' => 'nested' } }))).to eq('nested')
      expect(provider.parse_error(response_for({ 'message' => 'top level' }))).to eq('top level')
      expect(provider.parse_error(response_for({ 'detail' => 'detail field' }))).to eq('detail field')
    end

    it 'joins a list of errors' do
      body = [{ 'error' => 'first' }, { 'error' => { 'message' => 'second' } }]

      expect(provider.parse_error(response_for(body))).to eq('first. second')
    end

    it 'ignores empty error shapes and stringifies scalar list entries' do
      body = [nil, '', { 'error' => [] }, 'second', { 'message' => 'third' }]

      expect(provider.parse_error(response_for(body))).to eq('second. third')
      expect(provider.parse_error(response_for({ 'error' => [] }))).to be_nil
    end

    it 'passes a body it cannot interpret through' do
      expect(provider.parse_error(response_for(42))).to eq(42)
    end

    it 'parses a JSON string body' do
      expect(provider.parse_error(response_for('{"error":{"message":"parsed"}}'))).to eq('parsed')
    end

    it 'keeps an unparseable string body as text' do
      expect(provider.parse_error(response_for('plain text failure'))).to eq('plain text failure')
    end
  end

  describe 'provider registry partitions' do
    it 'splits providers into local and remote' do
      expect(described_class.local_providers.keys).to contain_exactly(:ollama, :gpustack)
      expect(described_class.remote_providers.keys).not_to include(:ollama, :gpustack)
      expect(described_class.local_providers.keys + described_class.remote_providers.keys).to match_array(
        described_class.providers.keys
      )
    end

    it 'lists only providers the configuration can reach' do
      config = config_for(:openai)

      expect(described_class.configured_providers(config)).to include(RubyLLM::Providers::OpenAI)
      expect(described_class.configured_remote_providers(config)).to include(RubyLLM::Providers::OpenAI)
      expect(described_class.configured_remote_providers(config)).not_to include(RubyLLM::Providers::Ollama)
    end
  end
end
