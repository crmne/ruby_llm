# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Perplexity::Router do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:perplexity, :router) }
  let(:chat) { RubyLLM.chat(model:, provider: :perplexity, protocol: :router_chat_completions) }
  let(:url) { 'https://api.perplexity.ai/router/v1/chat/completions' }
  let(:tool) do
    Class.new(RubyLLM::Tool) do
      description 'Add two integers.'
      parameter :left, type: :integer
      parameter :right, type: :integer
      define_method(:name) { 'add' }
      define_method(:execute) { |left:, right:| left + right }
    end
  end

  def completion(message = { role: 'assistant', content: '4' }, finish_reason: 'stop')
    { id: 'reply', model:, choices: [{ index: 0, message:, finish_reason: }],
      usage: { prompt_tokens: 100, completion_tokens: 8,
               prompt_tokens_details: { cached_tokens: 30, cache_write_tokens: 20 } } }
  end

  it 'selects Router explicitly while preserving Sonar and configured gateway base paths' do
    expect(RubyLLM::Providers::Perplexity.default_protocol).to eq(:chat_completions)
    expect(chat.provider.router_url('chat/completions')).to eq(url)
    ['https://gateway.test/perplexity', 'https://gateway.test/perplexity/router/v1/'].each do |base|
      context = RubyLLM.context { |config| config.perplexity_api_base = base }
      provider = RubyLLM::Providers::Perplexity.new(context.config)
      expect(provider.router_url('chat/completions')).to eq('https://gateway.test/perplexity/router/v1/chat/completions')
    end
  end

  it 'renders required and named tool choices, parallel controls, schema and cache boundaries through Chat' do
    chat.with_tools(tool).with_tool_options(choice: :required, calls: :one).with_caching
        .with_instructions('Use the documented arithmetic tools.').cache_until_here.ask_later('Add two and two.')
    payload = chat.render

    expect(payload).to include(tool_choice: :required, parallel_tool_calls: false,
                               prompt_cache_options: { mode: 'explicit' })
    expect(payload[:messages].first[:content].last).to include(prompt_cache_breakpoint: { mode: 'explicit' })
    expect(chat.with_tool_options(choice: 'add', calls: :many).render)
      .to include(tool_choice: { type: 'function', function: { name: :add } }, parallel_tool_calls: true)
    schema = { type: 'object', properties: { answer: { type: 'integer' } }, required: ['answer'] }
    expect(chat.with_schema(schema).render.dig(:response_format, :json_schema, :strict)).to be(true)
    expect(chat.with_caching(false).render).not_to have_key(:prompt_cache_options)
    expect(chat.render[:messages].first[:content]).to eq('Use the documented arithmetic tools.')
  end

  it 'executes and replays local tool results with reasoning context and normalized cache usage' do
    call = { role: 'assistant', content: nil, reasoning_content: 'Add the values.',
             tool_calls: [{ id: 'call_add', type: 'function',
                            function: { name: 'add', arguments: '{"left":2,"right":2}' } }] }
    payloads = []
    request = stub_request(:post, url).with { |req| payloads << JSON.parse(req.body) }
                                      .to_return_json(body: completion(call, finish_reason: 'tool_calls'))
                                      .then.to_return_json(body: completion)

    result = chat.with_tools(tool).ask('Add two and two.')

    expect(result.content).to eq('4')
    expect(result.tokens).to have_attributes(input: 50, output: 8, cache_read: 30, cache_write: 20)
    expect(payloads.last['messages']).to include(include('role' => 'tool', 'tool_call_id' => 'call_add',
                                                         'content' => '4'))
    expect(payloads.last['messages']).to include(include('role' => 'assistant',
                                                         'reasoning_content' => 'Add the values.'))
    expect(request).to have_been_requested.twice
  end

  it 'streams actual Router-shaped deltas and final usage through the public Chat API' do
    events = [{ choices: [{ index: 0, delta: { role: 'assistant', content: 'Hello' } }] },
              { choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] },
              completion.except(:choices).merge(choices: [])]
    body = "#{events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join}data: [DONE]\n\n"
    request = stub_request(:post, url).with do |req|
      JSON.parse(req.body).dig('stream_options', 'include_usage') == true
    end
                                      .to_return(body:, headers: { 'Content-Type' => 'text/event-stream' })
    chunks = []

    result = chat.ask('Say hello.') { |chunk| chunks << chunk }

    expect(chunks.filter_map(&:content).join).to eq('Hello')
    expect(result.content).to eq('Hello')
    expect(result.tokens).to have_attributes(input: 50, output: 8, cache_read: 30, cache_write: 20)
    expect(request).to have_been_requested.once
  end

  it 'serializes documented WAV audio input while keeping Sonar audio unsupported' do
    path = File.expand_path('../../../fixtures/ruby.wav', __dir__)
    payload = chat.ask_later('Transcribe this audio.', with: path).render
    part = payload[:messages].last[:content].last

    expect(part).to include(type: 'input_audio', input_audio: include(format: 'wav'))
    expect(Base64.decode64(part[:input_audio][:data])).to eq(File.binread(path))
    sonar = RubyLLM.chat(model: model_for(:perplexity), provider: :perplexity)
    expect { sonar.ask_later('Transcribe this audio.', with: path).render }
      .to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'rejects explicitly unsupported request controls before making a request' do
    [{ seed: 1 }, { modalities: ['audio'] }, { n: 2 }, { presence_penalty: 1 },
     { stream_options: { include_obfuscation: true } }].each do |options|
      expect { chat.with_provider_options(**options).ask_later('Hello').render }
        .to raise_error(ArgumentError, /Perplexity Router does not support/)
    end
    expect(a_request(:post, url)).not_to have_been_made
  end

  it 'requires tool descriptions and strict schemas without changing the default protocol' do
    unnamed = Class.new(RubyLLM::Tool) { define_method(:name) { 'undescribed' } }
    expect { chat.with_tools(unnamed).ask_later('Hello').render }
      .to raise_error(ArgumentError, /require a description/)
    schema = { name: 'answer', schema: { type: 'object', properties: {} }, strict: false }
    expect { described_class.new(chat.provider, chat.model).send(:render_payload, [], schema:) }
      .to raise_error(ArgumentError, /strict structured output/)
  end

  it 'requests a named tool with a cache boundary from the configured Router account', :live do
    skip_without_cassette_or_key('PERPLEXITY_API_KEY')
    response = chat.with_tools(tool).with_tool_options(choice: 'add', calls: :one).with_caching
                   .with_instructions('Use arithmetic tools for arithmetic.').cache_until_here
                   .ask_later('Add two and two.').generate

    expect(response.tool_calls.values.first).to have_attributes(name: 'add', arguments: { 'left' => 2, 'right' => 2 })
    expect(response.tokens.input).to be_a(Numeric)
  rescue RubyLLM::ForbiddenError => e
    raise unless e.message.include?('Router API is currently in limited preview')

    skip 'The configured Perplexity account has no Router preview access'
  end
end
