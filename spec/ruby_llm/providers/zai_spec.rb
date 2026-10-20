# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ZAI do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.zai_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:zai) }
  let(:completions_url) { 'https://api.z.ai/api/paas/v4/chat/completions' }

  def context
    RubyLLM.context { |context_config| context_config.zai_api_key = 'test-key' }
  end

  def stub_completion(message: { role: 'assistant', content: 'Hi' }, finish_reason: 'stop', usage: nil)
    stub_request(:post, completions_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: {
        id: 'chatcmpl-1', object: 'chat.completion', model: model_id,
        choices: [{ index: 0, message: message, finish_reason: finish_reason }],
        usage: usage || { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, completions_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  it "speaks Z.ai's dialect of Chat Completions" do
    expect(described_class.protocols).to eq(chat_completions: described_class::ChatCompletions)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Protocols::ChatCompletions)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[zai_api_key zai_api_base])
    expect(described_class.configuration_requirements).to eq(%i[zai_api_key])
  end

  it 'defaults to the international Z.ai endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.z.ai/api/paas/v4')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to BigModel when configured with its endpoint' do
    config.zai_api_base = 'https://open.bigmodel.cn/api/paas/v4'

    expect(provider.api_base).to eq('https://open.bigmodel.cn/api/paas/v4')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.remote_providers).to include(zai: described_class)
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev zai catalog' do
    expect(RubyLLM::Models::MODELS_DEV_PROVIDER_MAP).to include('zai' => 'zai')
    expect(RubyLLM.models.find(model_id, provider: :zai).context_window).to eq(1_000_000)
  end

  describe 'chat' do
    it 'sends instructions with the system role and the end user as user_id' do
      stub_completion

      context.chat(model: model_id, provider: :zai)
             .with_instructions('Answer in German.')
             .with_end_user('user-42')
             .ask('Hello')

      expect(sent_body).to include(
        'messages' => [{ 'role' => 'system', 'content' => 'Answer in German.' },
                       { 'role' => 'user', 'content' => 'Hello' }],
        'user_id' => 'user-42'
      )
    end

    it 'parses reasoning and counts cached input' do
      stub_completion(
        message: { role: 'assistant', content: '391', reasoning_content: '17 times 23 is 391.' },
        usage: { prompt_tokens: 100, completion_tokens: 30, total_tokens: 130,
                 prompt_tokens_details: { cached_tokens: 80 } }
      )

      response = context.chat(model: model_id, provider: :zai).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.tokens.input).to eq(20)
      expect(response.tokens.cache_read).to eq(80)
    end

    it 'names a blocked answer as filtered content' do
      stub_completion(finish_reason: 'sensitive')

      response = context.chat(model: model_id, provider: :zai).ask('Hello')

      expect(response.finish_reason).to eq(:content_filter)
    end

    it 'asks for thinking with an effort' do
      stub_completion

      context.chat(model: model_id, provider: :zai).with_thinking(effort: :high).ask('Hello')

      expect(sent_body).to include('thinking' => { 'type' => 'enabled' }, 'reasoning_effort' => 'high')
    end

    it 'turns thinking off on models with a toggle' do
      stub_completion

      context.chat(model: 'glm-4.7', provider: :zai).with_thinking(false).ask('Hello')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
      expect(sent_body).not_to have_key('reasoning_effort')
    end

    it 'sends earlier reasoning back as reasoning_content' do
      stub_completion
      chat = context.chat(model: model_id, provider: :zai)
      chat.add_message(role: :user, content: 'What is 17*23?')
      chat.add_message(role: :assistant, content: '391', thinking: RubyLLM::Thinking.build(text: 'Multiply.'))

      chat.ask('And 17*24?')

      expect(sent_body['messages'][1]).to eq('role' => 'assistant', 'content' => '391',
                                             'reasoning_content' => 'Multiply.')
    end

    it 'sends no prompt cache controls' do
      stub_completion

      context.chat(model: model_id, provider: :zai).with_caching(key: 'docs').ask('Hello')

      expect(sent_body.keys).not_to include('prompt_cache_key', 'prompt_cache_options')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Chat }

    it 'sends images as image_url parts' do
      image = RubyLLM::Attachment.new('https://example.com/ruby.png')

      content = protocol.render_content('What is this?', [image])

      expect(content.last).to eq(type: 'image_url', image_url: { url: 'https://example.com/ruby.png' })
    end

    it 'rejects documents and audio' do
      pdf = RubyLLM::Attachment.new(File.expand_path('../../fixtures/sample.pdf', __dir__))
      audio = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby.wav', __dir__))

      expect { protocol.render_content('Read this', [pdf]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      expect { protocol.render_content('Hear this', [audio]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end
  end
end
