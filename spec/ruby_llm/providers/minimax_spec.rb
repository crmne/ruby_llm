# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.minimax_api_key = 'test-key'
    end
  end
  let(:model_id) { model_for(:minimax) }
  let(:messages_url) { 'https://api.minimax.io/anthropic/v1/messages' }

  def context
    RubyLLM.context { |context_config| context_config.minimax_api_key = 'test-key' }
  end

  def stub_messages(body)
    stub_request(:post, messages_url)
      .with(headers: { 'Authorization' => 'Bearer test-key' })
      .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def sent_body
    body = nil
    expect(a_request(:post, messages_url).with { |request| body = JSON.parse(request.body) }).to have_been_made
    body
  end

  def reply(content, usage: { input_tokens: 10, output_tokens: 5 })
    {
      id: 'msg_1', type: 'message', role: 'assistant', model: model_id,
      content: content, stop_reason: 'end_turn', usage: usage
    }
  end

  it "speaks MiniMax's dialect of the Anthropic Messages API" do
    expect(described_class.protocols).to include(anthropic: described_class::Anthropic)
    expect(described_class.protocols.keys.first).to eq(:anthropic)
    expect(described_class::Anthropic.superclass).to eq(RubyLLM::Protocols::Anthropic)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[minimax_api_key minimax_api_base])
    expect(described_class.configuration_requirements).to eq(%i[minimax_api_key])
  end

  it 'defaults to the international Anthropic-compatible endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://api.minimax.io/anthropic')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.minimax_api_base = 'https://api.minimax.cn/anthropic'

    expect(provider.api_base).to eq('https://api.minimax.cn/anthropic')
  end

  it 'is a remote provider that requires an API key' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(minimax: described_class)
    expect(described_class).to be_remote
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'reads the models.dev minimax catalog' do
    expect(described_class.models_dev_provider_ids).to eq(%w[minimax])
    expect(RubyLLM.models.find(model_id, provider: :minimax).context_window).to eq(1_000_000)
  end

  it 'sends web search as the version MiniMax runs' do
    stub_messages(reply([{ type: 'text', text: 'Found it' }]))

    context.chat(model: model_id, provider: :minimax).with_provider_tools(:web_search).ask('Search the web')

    expect(sent_body['tools']).to eq([{ 'type' => 'web_search_20250305', 'name' => 'web_search' }])
  end

  it 'rejects the other provider tools, which the endpoint does not run' do
    chat = context.chat(model: model_id, provider: :minimax).with_provider_tools(:code_execution)

    expect { chat.ask('Run this') }.to raise_error(RubyLLM::UnsupportedServerToolError)
  end

  describe 'chat' do
    it 'parses thinking with its signature, and counts cached input' do
      stub_messages(reply(
                      [
                        { type: 'thinking', thinking: '17 times 23 is 391.', signature: 'abc123' },
                        { type: 'text', text: '391' }
                      ],
                      usage: { input_tokens: 18, output_tokens: 26, cache_creation_input_tokens: 0,
                               cache_read_input_tokens: 197, output_tokens_details: { thinking_tokens: 22 } }
                    ))

      response = context.chat(model: model_id, provider: :minimax).ask('What is 17*23?')

      expect(response.content).to eq('391')
      expect(response.thinking.text).to eq('17 times 23 is 391.')
      expect(response.thinking.signature).to eq('abc123')
      expect(response.tokens.input).to eq(18)
      expect(response.tokens.cache_read).to eq(197)
      expect(response.tokens.thinking).to eq(22)
    end

    it 'asks for adaptive thinking with an effort' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: model_id, provider: :minimax).with_thinking(effort: :low).ask('Hi')

      expect(sent_body).to include('thinking' => { 'type' => 'adaptive' }, 'output_config' => { 'effort' => 'low' })
    end

    it 'turns thinking off on models with a toggle' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: 'MiniMax-M3', provider: :minimax).with_thinking(false).ask('Hi')

      expect(sent_body['thinking']).to eq('type' => 'disabled')
    end
  end

  describe 'options MiniMax cannot carry' do
    def lookup_tool
      stub_const('LookupTool', Class.new(RubyLLM::Tool) do
        description 'Looks something up'

        def execute = 'found'
      end)
    end

    it 'raises for with_schema before sending, because its models ignore the schema' do
      chat = context.chat(model: model_id, provider: :minimax)
                    .with_schema({ type: 'object', properties: { fruit: { type: 'string' } } })

      expect { chat.ask('Name a fruit') }
        .to raise_error(ArgumentError, "MiniMax's Messages API has no structured output")
      expect(a_request(:post, messages_url)).not_to have_been_made
    end

    it 'raises for calls: :one before sending, because the API ignores it' do
      chat = context.chat(model: model_id, provider: :minimax).with_tools(lookup_tool).with_tool_options(calls: :one)

      expect { chat.ask('Look it up') }.to raise_error(ArgumentError, 'MiniMax does not accept calls: :one')
      expect(a_request(:post, messages_url)).not_to have_been_made
    end

    it 'still counts tokens for a chat with a schema and calls: :one' do
      stub_request(:post, 'https://api.minimax.io/anthropic/v1/messages/count_tokens')
        .to_return(status: 200, body: { input_tokens: 7 }.to_json, headers: { 'Content-Type' => 'application/json' })
      chat = context.chat(model: model_id, provider: :minimax)
                    .with_schema({ type: 'object', properties: { fruit: { type: 'string' } } })
                    .with_tools(lookup_tool).with_tool_options(choice: :auto, calls: :one)

      expect(chat.count_tokens('Hi')).to eq(7)
      expect(a_request(:post, 'https://api.minimax.io/anthropic/v1/messages/count_tokens').with do |request|
        JSON.parse(request.body)['tool_choice'] == { 'type' => 'auto' }
      end).to have_been_made
    end

    it 'ignores calls: :one on a request without tools' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: model_id, provider: :minimax).with_tool_options(calls: :one).ask('Hi')

      expect(sent_body).not_to include('tool_choice')
    end

    it 'allows calls: :many, which is what the API does anyway' do
      stub_messages(reply([{ type: 'text', text: 'Hi' }]))

      context.chat(model: model_id, provider: :minimax)
             .with_tools(lookup_tool).with_tool_options(calls: :many).ask('Hi')

      expect(sent_body).to include('tools')
    end
  end

  describe 'attachments' do
    let(:protocol) { described_class::Anthropic.new(provider, RubyLLM.models.find(model_id, provider: :minimax)) }

    it 'never uploads files to the provider' do
      expect(protocol.provider_file_references?).to be(false)
    end

    def rendered_blocks(*attachments)
      message = RubyLLM::Message.new(role: :user, content: 'What is this?', attachments:)
      protocol.send(:append_formatted_content, [], message)
    end

    it 'sends videos inline or by uploaded file, keeping attachment order' do
      stub_request(:get, 'https://example.com/clip.mp4')
        .to_return(status: 200, body: 'mp4 bytes', headers: { 'Content-Type' => 'video/mp4' })
      local = RubyLLM::Attachment.new(File.expand_path('../../fixtures/ruby_clip.mp4', __dir__))
      remote = RubyLLM::Attachment.new('https://example.com/clip.mp4')
      image = RubyLLM::Attachment.new('https://example.com/ruby.png', mime_type: 'image/png')
      upload = RubyLLM::Attachment.new(RubyLLM::UploadedFile.new(id: '42', provider: 'minimax', mime_type: 'video/mp4'))

      expect(rendered_blocks(local, image, remote, upload).drop(1)).to eq(
        [
          { type: 'video', source: { type: 'base64', media_type: 'video/mp4', data: local.encoded } },
          { type: 'image', source: { type: 'url', url: 'https://example.com/ruby.png' } },
          { type: 'video', source: { type: 'base64', media_type: 'video/mp4', data: remote.encoded } },
          { type: 'video', source: { type: 'url', url: 'mm_file://42' } }
        ]
      )
    end

    it 'names QuickTime videos the way MiniMax documents them' do
      video = RubyLLM::Attachment.new(StringIO.new('mov'), filename: 'clip.mov', mime_type: 'video/quicktime')

      expect(rendered_blocks(video).last.dig(:source, :media_type)).to eq('video/mov')
    end

    it 'accepts video attachments' do
      video = RubyLLM::Attachment.new('https://example.com/clip.mp4', mime_type: 'video/mp4')

      expect(protocol.supported_attachment?(video)).to be(true)
    end
  end
end
