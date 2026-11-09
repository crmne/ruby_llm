# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Hetzner do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.hetzner_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:hetzner) }

  it 'speaks the Hetzner dialect of Chat Completions' do
    expect(described_class.protocols).to include(chat_completions: described_class::ChatCompletions)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Protocols::ChatCompletions)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[hetzner_api_key hetzner_api_base])
    expect(described_class.configuration_requirements).to eq(%i[hetzner_api_key])
  end

  it 'defaults to the Hetzner Inference endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://inference.hetzner.com/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.hetzner_api_base = 'https://hetzner-proxy.example.com/api/v1'

    expect(provider.api_base).to eq('https://hetzner-proxy.example.com/api/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(hetzner: described_class)
    expect(described_class).to be_remote
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'allows model ids missing from the registry' do
    expect(described_class.assume_models_exist?).to be(true)
  end

  it 'reads the models.dev hetzner catalog' do
    expect(described_class.models_dev_provider_ids).to eq(%w[hetzner])
  end

  it 'reads string error bodies' do
    response = instance_double(Faraday::Response, body: '{"error":"unauthorized"}')

    expect(provider.parse_error(response)).to eq('unauthorized')
  end

  describe 'chat' do
    before do
      stub_request(:post, 'https://inference.hetzner.com/v1/chat/completions')
        .with(headers: { 'Authorization' => 'Bearer test-key' })
        .to_return(status: 200, body: {
          id: 'chatcmpl-1',
          object: 'chat.completion',
          model: model_id,
          choices: [{
            index: 0,
            message: { role: 'assistant', content: 'Hallo!' },
            finish_reason: 'stop'
          }],
          usage: { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 }
        }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends instructions with the system role and parses the reply' do
      context = RubyLLM.context { |context_config| context_config.hetzner_api_key = 'test-key' }

      response = context.chat(model: model_id, provider: :hetzner)
                        .with_instructions('Answer in German.')
                        .ask('Hello')

      expect(response.content).to eq('Hallo!')
      expect(response.tokens.input).to eq(12)
      expect(response.tokens.output).to eq(3)
      expect(
        a_request(:post, 'https://inference.hetzner.com/v1/chat/completions').with do |request|
          body = JSON.parse(request.body)
          instructions = { 'role' => 'system', 'content' => 'Answer in German.' }
          body['model'] == model_id && body['messages'].first == instructions
        end
      ).to have_been_made.once
    end
  end

  describe 'thinking controls' do
    def rejected_effort
      { error: { message: 'Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low.',
                 type: 'BadRequestError', param: nil, code: 400 } }
    end

    it 'reports a reasoning effort the model rejects as an unsupported thinking parameter' do
      stub_request(:post, 'https://inference.hetzner.com/v1/chat/completions')
        .to_return(status: 400, body: rejected_effort.to_json, headers: { 'Content-Type' => 'application/json' })
      context = RubyLLM.context { |context_config| context_config.hetzner_api_key = 'test-key' }

      chat = context.chat(model: model_id, provider: :hetzner).with_thinking(effort: :high)

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::UnsupportedParameterError) { |error|
        expect(error.parameter).to eq(:thinking)
        expect(error.message).to include('Supported types are xhigh')
      }
    end

    it 'leaves other bad requests as they are' do
      body = { error: { message: 'Invalid response_format', type: 'BadRequestError', param: nil, code: 400 } }
      stub_request(:post, 'https://inference.hetzner.com/v1/chat/completions')
        .to_return(status: 400, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
      context = RubyLLM.context { |context_config| context_config.hetzner_api_key = 'test-key' }

      expect { context.chat(model: model_id, provider: :hetzner).ask('Hello') }
        .to raise_error(RubyLLM::BadRequestError) { |error|
          expect(error).not_to be_a(RubyLLM::UnsupportedParameterError)
        }
    end

    context 'with the live API', :live do
      include_context 'with configured RubyLLM'

      it 'thinks at the efforts Qwen3.8-27B takes' do
        response = RubyLLM.chat(model: model_id, provider: :hetzner)
                          .with_thinking(effort: :xhigh)
                          .ask('What is 17 times 23? Reply with the number.')

        expect(response.content).to include('391')
        expect(response.thinking&.text).to be_present
      end

      it 'names thinking when Qwen3.8-27B rejects an effort' do
        chat = RubyLLM.chat(model: model_id, provider: :hetzner).with_thinking(effort: :high)

        expect { chat.ask('Say ok') }.to raise_error(RubyLLM::UnsupportedParameterError) { |error|
          expect(error.parameter).to eq(:thinking)
        }
      end
    end
  end

  describe 'prompt caching' do
    let(:chat) do
      RubyLLM.context { |context_config| context_config.hetzner_api_key = 'test-key' }
             .chat(model: model_id, provider: :hetzner)
    end

    it 'marks no cache boundary, because the API ignores one' do
      chat.add_message(role: :user, content: 'A long handbook').cache_until_here

      rendered = chat.render

      expect(rendered.to_json).not_to include('prompt_cache_breakpoint')
      expect(rendered[:messages].first[:content]).to eq('A long handbook')
    end

    it 'sends no cache key, because caching takes no request option' do
      chat.with_caching(key: 'tenant-1').add_message(role: :user, content: 'Hello')

      expect(chat.render).not_to include(:prompt_cache_key)
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Chat }

    it 'sends remote images inline, because Hetzner cannot fetch URLs' do
      png = File.binread(File.expand_path('../../fixtures/ruby.png', __dir__))
      stub_request(:get, 'https://example.com/ruby.png')
        .to_return(body: png, headers: { 'Content-Type' => 'image/png' })
      image = RubyLLM::Attachment.new('https://example.com/ruby.png')

      content = protocol.render_content('What is this?', [image])

      data_url = "data:image/png;base64,#{Base64.strict_encode64(png)}"
      expect(content.last).to eq(type: 'image_url', image_url: { url: data_url })
    end

    it 'rejects documents and audio, which the models do not accept' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../fixtures/sample.pdf', __dir__))
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect { protocol.render_content('Read this', [pdf]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      expect { protocol.render_content('Hear this', [audio]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end

  describe 'model listing' do
    let(:response) do
      instance_double(
        Faraday::Response,
        body: {
          'object' => 'list',
          'data' => [
            { 'id' => 'Qwen/Qwen3.6-35B-A3B-FP8', 'object' => 'model', 'created' => 1_776_384_000,
              'owned_by' => 'hetzner' },
            { 'id' => 'Qwen3.8-27B', 'object' => 'model', 'created' => 1_786_665_600, 'owned_by' => 'hetzner' }
          ]
        }
      )
    end

    it 'reads the OpenAI-compatible model list' do
      models = described_class::ChatCompletions.allocate.send(:parse_list_models_response, response, 'hetzner')

      expect(models.map(&:id)).to eq(%w[Qwen/Qwen3.6-35B-A3B-FP8 Qwen3.8-27B])
      expect(models.map(&:provider).uniq).to eq(['hetzner'])
    end
  end
end
