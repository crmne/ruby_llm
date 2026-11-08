# frozen_string_literal: true

require 'spec_helper'

# Each provider's base URL setting accepts the forms people paste from the
# provider's documentation or SDK, and sends the same request for all of them.
RSpec.describe RubyLLM::Provider do
  def provider_with(slug, settings)
    config = RubyLLM::Configuration.new
    config.public_send(:"#{slug}_api_key=", 'key') if config.respond_to?(:"#{slug}_api_key=")
    settings.each { |setting, value| config.public_send(:"#{setting}=", value) }
    described_class.providers.fetch(slug).new(config)
  end

  def request_url(connection, path)
    connection.connection.build_url(path).to_s
  end

  def self.openai_compatible(base)
    root = base.sub(%r{\A(https?://[^/]+).*\z}, '\1')
    version = base.delete_prefix(root)
    [
      root, "#{root}/", *("#{root}/api" if version.start_with?('/api/')), base, "#{base}/",
      "#{base}/chat/completions", "#{base}/chat/completions/", "#{base}/completions", "#{base}/responses",
      "#{base}/embeddings"
    ]
  end

  {
    openai: {
      setting: :openai_api_base, path: 'chat/completions',
      accepted: {
        'https://api.openai.com/v1/chat/completions' => [nil, *openai_compatible('https://api.openai.com/v1')],
        'https://gateway.example.com/openai/chat/completions' => [
          'https://gateway.example.com/openai', 'https://gateway.example.com/openai/',
          'https://gateway.example.com/openai/chat/completions'
        ],
        'http://localhost:8080/v1/chat/completions' => ['http://localhost:8080', 'http://localhost:8080/v1/']
      },
      ambiguous: ['api.openai.com/v1', 'localhost:8080/v1', '/v1', 'https://']
    },
    mistral: {
      setting: :mistral_api_base, path: 'chat/completions',
      accepted: {
        'https://api.mistral.ai/v1/chat/completions' => [nil, *openai_compatible('https://api.mistral.ai/v1')]
      },
      ambiguous: ['api.mistral.ai']
    },
    xai: {
      setting: :xai_api_base, path: 'responses',
      accepted: { 'https://api.x.ai/v1/responses' => [nil, *openai_compatible('https://api.x.ai/v1')] },
      ambiguous: ['api.x.ai/v1']
    },
    moonshot: {
      setting: :moonshot_api_base, path: 'chat/completions',
      accepted: {
        'https://api.moonshot.ai/v1/chat/completions' => [nil, *openai_compatible('https://api.moonshot.ai/v1')],
        'https://api.moonshot.cn/v1/chat/completions' => openai_compatible('https://api.moonshot.cn/v1')
      },
      ambiguous: ['api.moonshot.ai']
    },
    hetzner: {
      setting: :hetzner_api_base, path: 'chat/completions',
      accepted: {
        'https://inference.hetzner.com/v1/chat/completions' => [nil, *openai_compatible('https://inference.hetzner.com/v1')]
      },
      ambiguous: ['inference.hetzner.com']
    },
    meta: {
      setting: :meta_api_base, path: 'responses',
      accepted: { 'https://api.meta.ai/v1/responses' => [nil, *openai_compatible('https://api.meta.ai/v1')] },
      ambiguous: ['api.meta.ai']
    },
    ollama: {
      setting: :ollama_api_base, path: 'chat/completions',
      accepted: {
        'http://localhost:11434/v1/chat/completions' => openai_compatible('http://localhost:11434/v1'),
        'http://localhost:3000/api/chat/completions' => ['http://localhost:3000/api', 'http://localhost:3000/api/']
      },
      ambiguous: ['localhost:11434', 'localhost:11434/v1']
    },
    ollama_cloud: {
      setting: :ollama_cloud_api_base, path: 'chat/completions',
      accepted: { 'https://ollama.com/v1/chat/completions' => [nil, *openai_compatible('https://ollama.com/v1')] },
      ambiguous: ['ollama.com/v1']
    },
    gpustack: {
      setting: :gpustack_api_base, path: 'chat/completions',
      accepted: {
        'http://gpustack.local/v1/chat/completions' => openai_compatible('http://gpustack.local/v1'),
        'http://gpustack.local/model/proxy/7/v1/chat/completions' => [
          'http://gpustack.local/model/proxy/7/v1', 'http://gpustack.local/model/proxy/7/v1/',
          'http://gpustack.local/model/proxy/7/v1/chat/completions'
        ]
      },
      ambiguous: ['gpustack.local/v1']
    },
    openrouter: {
      setting: :openrouter_api_base, path: 'chat/completions',
      accepted: {
        'https://openrouter.ai/api/v1/chat/completions' => [nil, *openai_compatible('https://openrouter.ai/api/v1')]
      },
      ambiguous: ['openrouter.ai/api/v1']
    },
    zai: {
      setting: :zai_api_base, path: 'chat/completions',
      accepted: {
        'https://api.z.ai/api/paas/v4/chat/completions' => [nil, *openai_compatible('https://api.z.ai/api/paas/v4')],
        'https://open.bigmodel.cn/api/paas/v4/chat/completions' => openai_compatible('https://open.bigmodel.cn/api/paas/v4')
      },
      ambiguous: ['api.z.ai/api/paas/v4']
    },
    deepseek: {
      setting: :deepseek_api_base, path: 'chat/completions',
      accepted: {
        'https://api.deepseek.com/chat/completions' => [
          nil, 'https://api.deepseek.com', 'https://api.deepseek.com/', 'https://api.deepseek.com/chat/completions'
        ],
        'https://api.deepseek.com/v1/chat/completions' => [
          'https://api.deepseek.com/v1', 'https://api.deepseek.com/v1/', 'https://api.deepseek.com/v1/chat/completions'
        ]
      },
      ambiguous: ['api.deepseek.com']
    },
    perplexity: {
      setting: :perplexity_api_base, path: 'v1/embeddings',
      accepted: {
        'https://api.perplexity.ai/v1/embeddings' => [
          nil, 'https://api.perplexity.ai', 'https://api.perplexity.ai/', 'https://api.perplexity.ai/v1',
          'https://api.perplexity.ai/v1/', 'https://api.perplexity.ai/chat/completions',
          'https://api.perplexity.ai/v1/chat/completions', 'https://api.perplexity.ai/v1/embeddings',
          'https://api.perplexity.ai/v1/agent', 'https://api.perplexity.ai/router/v1',
          'https://api.perplexity.ai/router/v1/chat/completions'
        ]
      },
      ambiguous: ['api.perplexity.ai']
    },
    anthropic: {
      setting: :anthropic_api_base, path: 'v1/messages',
      accepted: {
        'https://api.anthropic.com/v1/messages' => [
          nil, 'https://api.anthropic.com', 'https://api.anthropic.com/', 'https://api.anthropic.com/v1',
          'https://api.anthropic.com/v1/', 'https://api.anthropic.com/v1/messages', 'https://api.anthropic.com/v1/messages/'
        ],
        'https://gateway.example.com/anthropic/v1/messages' => [
          'https://gateway.example.com/anthropic', 'https://gateway.example.com/anthropic/v1',
          'https://gateway.example.com/anthropic/v1/messages'
        ]
      },
      ambiguous: ['api.anthropic.com', 'api.anthropic.com/v1/messages']
    },
    minimax: {
      setting: :minimax_api_base, path: 'v1/messages',
      accepted: {
        'https://api.minimax.io/anthropic/v1/messages' => [
          nil, 'https://api.minimax.io', 'https://api.minimax.io/anthropic', 'https://api.minimax.io/anthropic/',
          'https://api.minimax.io/anthropic/v1', 'https://api.minimax.io/anthropic/v1/messages'
        ],
        'https://api.minimax.cn/anthropic/v1/messages' => ['https://api.minimax.cn/anthropic/']
      },
      ambiguous: ['api.minimax.io/anthropic']
    },
    cohere: {
      setting: :cohere_api_base, path: 'v2/chat',
      accepted: {
        'https://api.cohere.com/v2/chat' => [
          nil, 'https://api.cohere.com', 'https://api.cohere.com/', 'https://api.cohere.com/v1', 'https://api.cohere.com/v2',
          'https://api.cohere.com/v2/', 'https://api.cohere.com/v2/chat', 'https://api.cohere.com/v2/embed',
          'https://api.cohere.com/v2/rerank'
        ]
      },
      ambiguous: ['api.cohere.com']
    },
    deepgram: {
      setting: :deepgram_api_base, path: 'v1/listen',
      accepted: {
        'https://api.deepgram.com/v1/listen' => [
          nil, 'https://api.deepgram.com', 'https://api.deepgram.com/', 'https://api.deepgram.com/v1',
          'https://api.deepgram.com/v1/listen', 'https://api.deepgram.com/v1/speak'
        ]
      },
      ambiguous: ['api.deepgram.com']
    },
    elevenlabs: {
      setting: :elevenlabs_api_base, path: 'v1/speech-to-text',
      accepted: {
        'https://api.elevenlabs.io/v1/speech-to-text' => [
          nil, 'https://api.elevenlabs.io', 'https://api.elevenlabs.io/', 'https://api.elevenlabs.io/v1',
          'https://api.elevenlabs.io/v1/speech-to-text', 'https://api.elevenlabs.io/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb'
        ],
        'https://api.eu.residency.elevenlabs.io/v1/speech-to-text' => ['https://api.eu.residency.elevenlabs.io/v1/']
      },
      ambiguous: ['api.elevenlabs.io']
    },
    typesafe: {
      setting: :typesafe_api_base, path: 'v1/systemone',
      accepted: {
        'https://api.typesafe.ai/v1/systemone' => [
          nil, 'https://api.typesafe.ai', 'https://api.typesafe.ai/', 'https://api.typesafe.ai/v1',
          'https://api.typesafe.ai/v1/systemone'
        ]
      },
      ambiguous: ['api.typesafe.ai']
    },
    gemini: {
      setting: :gemini_api_base, path: 'models/gemini-2.5-flash:generateContent',
      accepted: {
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent' => [
          nil, 'https://generativelanguage.googleapis.com', 'https://generativelanguage.googleapis.com/',
          'https://generativelanguage.googleapis.com/v1beta', 'https://generativelanguage.googleapis.com/v1beta/',
          'https://generativelanguage.googleapis.com/v1beta/models',
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse'
        ],
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent' => [
          'https://generativelanguage.googleapis.com/v1', 'https://generativelanguage.googleapis.com/v1/',
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent'
        ]
      },
      ambiguous: [
        'generativelanguage.googleapis.com/v1beta',
        'https://generativelanguage.googleapis.com/v1beta/openai',
        'https://generativelanguage.googleapis.com/v1beta/openai/',
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
      ]
    }
  }.each do |slug, table|
    describe "#{table[:setting]} forms" do
      table[:accepted].each do |url, forms|
        forms.each do |form|
          it "sends #{form.inspect} to #{url}" do
            provider = provider_with(slug, table[:setting] => form)

            expect(request_url(provider.connection, table[:path])).to eq(url)
          end
        end
      end

      table[:ambiguous].each do |form|
        it "rejects #{form.inspect}, naming the forms it accepts" do
          expect { provider_with(slug, table[:setting] => form) }.to raise_error(
            RubyLLM::ConfigurationError, /#{table[:setting]} must be a base URL such as .*trailing slash/
          )
        end
      end
    end
  end

  it 'names the API version the base URL may leave out' do
    expect { provider_with(:openai, openai_api_base: 'api.openai.com') }.to raise_error(
      RubyLLM::ConfigurationError,
      'openai_api_base must be a base URL such as https://api.openai.com/v1. RubyLLM accepts it with or without ' \
      '/v1 and with or without a trailing slash, or a full endpoint URL from the provider\'s documentation. ' \
      'Got "api.openai.com".'
    )
  end

  it 'names no version for a provider whose base URL has none' do
    expect { provider_with(:anthropic, anthropic_api_base: 'api.anthropic.com') }.to raise_error(
      RubyLLM::ConfigurationError, /RubyLLM accepts it with or without a trailing slash/
    )
  end

  describe 'bedrock_api_base forms' do
    def bedrock(settings)
      provider_with(:bedrock, { bedrock_region: 'us-east-1', bedrock_secret_key: 'secret' }.merge(settings))
    end

    path = '/model/anthropic.claude-haiku-4-5-20251001-v1:0/converse'
    {
      "https://bedrock-runtime.us-east-1.amazonaws.com#{path}" => [
        nil, 'https://bedrock-runtime.us-east-1.amazonaws.com', 'https://bedrock-runtime.us-east-1.amazonaws.com/',
        "https://bedrock-runtime.us-east-1.amazonaws.com#{path}",
        'https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude-haiku-4-5-20251001-v1:0/invoke',
        'https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-lite-v1%3A0/converse-stream',
        'https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.nova-lite-v1:0'
      ],
      "http://gateway:8080/bedrock#{path}" => ['http://gateway:8080/bedrock', 'http://gateway:8080/bedrock/']
    }.each do |url, forms|
      forms.each do |form|
        it "sends #{form.inspect} to #{url}" do
          expect(request_url(bedrock(bedrock_api_base: form).connection, path.delete_prefix('/'))).to eq(url)
        end
      end
    end

    it 'normalizes the control and agent endpoints the same way' do
      provider = bedrock(bedrock_api_base: 'http://gateway:8080/bedrock/model/amazon.nova-lite-v1:0/converse')

      expect([provider.control_api_base, provider.agent_api_base]).to all(eq('http://gateway:8080/bedrock'))
    end

    {
      'https://bedrock-mantle.us-east-1.api.aws/v1/chat/completions' => [
        nil, 'https://bedrock-mantle.us-east-1.api.aws', 'https://bedrock-mantle.us-east-1.api.aws/',
        'https://bedrock-mantle.us-east-1.api.aws/v1', 'https://bedrock-mantle.us-east-1.api.aws/v1/',
        'https://bedrock-mantle.us-east-1.api.aws/v1/chat/completions',
        'https://bedrock-mantle.us-east-1.api.aws/v1/responses',
        'https://bedrock-mantle.us-east-1.api.aws/openai/v1',
        'https://bedrock-mantle.us-east-1.api.aws/openai/v1/responses',
        'https://bedrock-mantle.us-east-1.api.aws/anthropic/v1/messages'
      ],
      'http://gateway:8080/mantle/v1/chat/completions' => ['http://gateway:8080/mantle', 'http://gateway:8080/mantle/']
    }.each do |url, forms|
      forms.each do |form|
        it "sends bedrock_mantle_api_base #{form.inspect} to #{url}" do
          provider = bedrock(bedrock_mantle_api_base: form)

          expect(request_url(provider.mantle_connection, 'v1/chat/completions')).to eq(url)
        end
      end
    end

    ['bedrock-runtime.us-east-1.amazonaws.com', 'https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1',
     'https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1/chat/completions'].each do |form|
      it "rejects #{form.inspect}, naming the forms it accepts" do
        expect { bedrock(bedrock_api_base: form) }.to raise_error(
          RubyLLM::ConfigurationError, /bedrock_api_base must be a base URL such as .*trailing slash/
        )
      end
    end
  end

  describe 'vertexai_api_base forms' do
    def vertex(settings)
      provider_with(:vertexai, { vertexai_project_id: 'proj', vertexai_location: 'us-central1' }.merge(settings))
    end

    path = 'projects/proj/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent'
    {
      "https://us-central1-aiplatform.googleapis.com/v1beta1/#{path}" => [
        nil, 'https://us-central1-aiplatform.googleapis.com', 'https://us-central1-aiplatform.googleapis.com/',
        'https://us-central1-aiplatform.googleapis.com/v1beta1/',
        "https://us-central1-aiplatform.googleapis.com/v1beta1/#{path}"
      ],
      "https://us-central1-aiplatform.googleapis.com/v1/#{path}" => [
        'https://us-central1-aiplatform.googleapis.com/v1', "https://us-central1-aiplatform.googleapis.com/v1/#{path}"
      ]
    }.each do |url, forms|
      forms.each do |form|
        it "sends #{form.inspect} to #{url}" do
          expect(request_url(vertex(vertexai_api_base: form).connection, path)).to eq(url)
        end
      end
    end

    it 'accepts the ranking base with a trailing slash or a full endpoint URL' do
      rank = 'projects/proj/locations/global/rankingConfigs/default:rank'
      ['https://discoveryengine.googleapis.com/', "https://discoveryengine.googleapis.com/v1/#{rank}"].each do |form|
        connection = vertex(vertexai_ranking_api_base: form).ranking_connection

        expect(request_url(connection, rank)).to eq("https://discoveryengine.googleapis.com/v1/#{rank}")
      end
    end

    it 'rejects a base without a scheme' do
      expect { vertex(vertexai_api_base: 'us-central1-aiplatform.googleapis.com') }.to raise_error(
        RubyLLM::ConfigurationError, /vertexai_api_base must be a base URL such as .*v1beta1/
      )
    end
  end

  describe 'azure_api_base forms' do
    def chat_url(form)
      provider = provider_with(:azure, azure_api_base: form)
      protocol = RubyLLM::Providers::Azure::ChatCompletions.new(provider, nil)

      request_url(provider.connection, protocol.completion_url)
    end

    {
      'https://res.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview' => [
        'https://res.services.ai.azure.com', 'https://res.services.ai.azure.com/',
        'https://res.services.ai.azure.com/models', 'https://res.services.ai.azure.com/models/',
        'https://res.services.ai.azure.com/models/chat/completions',
        'https://res.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview'
      ],
      'https://res.openai.azure.com/openai/v1/chat/completions' => [
        'https://res.openai.azure.com/openai', 'https://res.openai.azure.com/openai/',
        'https://res.openai.azure.com/openai/v1', 'https://res.openai.azure.com/openai/v1/',
        'https://res.openai.azure.com/openai/v1/chat/completions', 'https://res.openai.azure.com/openai/v1/responses',
        'https://res.openai.azure.com/openai/v1/embeddings'
      ],
      'https://res.openai.azure.com/openai/deployments/gpt/chat/completions?api-version=2024-05-01-preview' => [
        'https://res.openai.azure.com/openai/deployments/gpt', 'https://res.openai.azure.com/openai/deployments/gpt/',
        'https://res.openai.azure.com/openai/deployments/gpt/chat/completions',
        'https://res.openai.azure.com/openai/deployments/gpt/embeddings'
      ],
      'https://res.openai.azure.com/openai/deployments/gpt/chat/completions?api-version=2025-01-01' => [
        'https://res.openai.azure.com/openai/deployments/gpt?api-version=2025-01-01',
        'https://res.openai.azure.com/openai/deployments/gpt/?api-version=2025-01-01',
        'https://res.openai.azure.com/openai/deployments/gpt/chat/completions?api-version=2025-01-01'
      ]
    }.each do |url, forms|
      forms.each do |form|
        it "sends #{form.inspect} to #{url}" do
          expect(chat_url(form)).to eq(url)
        end
      end
    end

    it 'keeps the api-version out of the base that other endpoints build on' do
      provider = provider_with(:azure, azure_api_base: 'https://res.openai.azure.com/openai/v1/?api-version=preview')

      expect(provider.azure_openai_v1_base).to eq('https://res.openai.azure.com/openai/v1')
    end

    it 'keeps batches and files on the openai/v1 base whatever the path tail' do
      provider = provider_with(:azure, azure_api_base: 'https://res.openai.azure.com/openai/v1/responses/')

      expect(provider.azure_openai_v1_base).to eq('https://res.openai.azure.com/openai/v1')
    end

    ['res.openai.azure.com', 'https://res.openai.azure.com/openai/deployments',
     'https://res.openai.azure.com/openai/deployments/'].each do |form|
      it "rejects #{form.inspect}, naming the forms it accepts" do
        expect { provider_with(:azure, azure_api_base: form) }.to raise_error(
          RubyLLM::ConfigurationError, /azure_api_base (must be a base URL such as|names no deployment)/
        )
      end
    end
  end
end
