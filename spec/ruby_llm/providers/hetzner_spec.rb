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
    expect(provider.api_base).to eq('https://inference.hetzner.com/api/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.hetzner_api_base = 'https://hetzner-proxy.example.com/api/v1'

    expect(provider.api_base).to eq('https://hetzner-proxy.example.com/api/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.remote_providers).to include(hetzner: described_class)
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'allows model ids missing from the registry' do
    expect(described_class.assume_models_exist?).to be(true)
  end

  it 'reads the models.dev hetzner catalog' do
    expect(RubyLLM::Models::MODELS_DEV_PROVIDER_MAP).to include('hetzner' => 'hetzner')
  end

  it 'reads string error bodies' do
    response = instance_double(Faraday::Response, body: '{"error":"unauthorized"}')

    expect(provider.parse_error(response)).to eq('unauthorized')
  end

  describe 'chat' do
    before do
      stub_request(:post, 'https://inference.hetzner.com/api/v1/chat/completions')
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
        a_request(:post, 'https://inference.hetzner.com/api/v1/chat/completions').with do |request|
          body = JSON.parse(request.body)
          instructions = { 'role' => 'system', 'content' => 'Answer in German.' }
          body['model'] == model_id && body['messages'].first == instructions
        end
      ).to have_been_made.once
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
