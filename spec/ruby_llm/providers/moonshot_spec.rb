# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Moonshot do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.moonshot_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:moonshot) }
  let(:completions_url) { 'https://api.moonshot.ai/v1/chat/completions' }

  def context
    RubyLLM.context { |context_config| context_config.moonshot_api_key = 'test-key' }
  end

  def stub_completion(message: { role: 'assistant', content: 'Hi' }, usage: nil)
    stub_request(:post, completions_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'chatcmpl-1', object: 'chat.completion', model: model_id,
        choices: [{ index: 0, message: message, finish_reason: 'stop' }],
        usage: usage || { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, completions_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Moonshot's dialect of Chat Completions" do
    expect(described_class.protocols).to eq(chat_completions: described_class::ChatCompletions)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Protocols::ChatCompletions)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[moonshot_api_key moonshot_api_base])
    expect(described_class.configuration_requirements).to eq(%i[moonshot_api_key])
  end

  it 'defaults to the international Moonshot endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.moonshot.ai/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.moonshot_api_base = 'https://api.moonshot.cn/v1'

    expect(provider.api_base).to eq('https://api.moonshot.cn/v1')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.remote_providers).to include(moonshot: described_class)
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev moonshotai catalog' do
    expect(RubyLLM::Models::MODELS_DEV_PROVIDER_MAP).to include('moonshotai' => 'moonshot')
    expect(RubyLLM.models.find('kimi-k3', provider: :moonshot).context_window).to eq(1_048_576)
  end

  describe 'chat' do
    it 'sends instructions with the system role, the output limit, and the end user' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot)
             .with_instructions('Answer in German.')
             .with_max_output_tokens(1000)
             .with_end_user('user-42')
             .ask('Hello')

      expect(sent_body).to include(
        'messages' => [{ 'role' => 'system', 'content' => 'Answer in German.' },
                       { 'role' => 'user', 'content' => 'Hello' }],
        'max_completion_tokens' => 1000,
        'safety_identifier' => 'user-42'
      )
    end

    it 'parses reasoning and counts cache reads and writes' do
      stub_completion(
        message: { role: 'assistant', content: '391', reasoning_content: '17 times 23 is 391.' },
        usage: { prompt_tokens: 100, completion_tokens: 30, total_tokens: 130, cached_tokens: 60,
                 prompt_tokens_details: { cached_tokens: 60, cache_write_tokens: 30 } }
      )

      response = context.chat(model: model_id, provider: :moonshot).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.tokens.input).to eq(10)
      expect(response.tokens.cache_read).to eq(60)
      expect(response.tokens.cache_write).to eq(30)
    end

    it 'turns thinking on and off on models with a toggle' do
      stub_completion

      context.chat(model: 'kimi-k2.6', provider: :moonshot).with_thinking(false).ask('Hello')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
    end

    it 'sets the effort of models that always think' do
      stub_completion

      context.chat(model: 'kimi-k3', provider: :moonshot).with_thinking(effort: :max).ask('Hello')

      expect(sent_body).to include('reasoning_effort' => 'max')
      expect(sent_body).not_to have_key('thinking')
    end

    it 'sends earlier reasoning back as reasoning_content' do
      stub_completion
      chat = context.chat(model: model_id, provider: :moonshot)
      chat.add_message(role: :user, content: 'What is 17*23?')
      chat.add_message(role: :assistant, content: '391', thinking: RubyLLM::Thinking.build(text: 'Multiply.'))

      chat.ask('And 17*24?')

      expect(sent_body['messages'][1]).to eq('role' => 'assistant', 'content' => '391',
                                             'reasoning_content' => 'Multiply.')
    end

    it 'sends a prompt cache key and lifetime without breakpoints' do
      stub_completion

      context.chat(model: model_id, provider: :moonshot).with_caching(key: 'docs', ttl: '1h').ask('Hello')

      expect(sent_body).to include('prompt_cache_key' => 'docs', 'prompt_cache_options' => { 'ttl' => '1h' })
      expect(sent_body.to_json).not_to include('prompt_cache_breakpoint')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Chat }

    it 'sends remote images inline, because Moonshot reads only data URIs' do
      image = RubyLLM::Attachment.new('https://example.com/ruby.png')
      stub_request(:get, 'https://example.com/ruby.png')
        .to_return(status: 200, body: 'png bytes', headers: { 'Content-Type' => 'image/png' })

      content = protocol.render_content('What is this?', [image])

      data_uri = "data:image/png;base64,#{Base64.strict_encode64('png bytes')}"
      expect(content.last).to eq(type: 'image_url', image_url: { url: data_uri })
    end

    it 'rejects documents and audio' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../fixtures/sample.pdf', __dir__))
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect { protocol.render_content('Read this', [pdf]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      expect { protocol.render_content('Hear this', [audio]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end
end
