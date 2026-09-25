# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Perplexity::Agent do
  include_context 'with configured RubyLLM'

  let(:url) { 'https://api.perplexity.ai/v1/agent' }
  let(:chat) { RubyLLM.chat(model: model_for(:perplexity, :agent), provider: :perplexity) }
  let(:add_tool) do
    Class.new(RubyLLM::Tool) do
      description 'Add two integers.'
      parameter :left, type: :integer
      parameter :right, type: :integer
      define_method(:name) { 'add' }
      define_method(:execute) { |left:, right:| left + right }
    end
  end

  def response_body(text = 'Rails was created by David Heinemeier Hansson.[1]')
    {
      id: 'resp_1', object: 'response', status: 'completed', model: 'openai/gpt-5-mini',
      output: [
        { type: 'search_results', queries: ['rails creator'],
          results: [
            { id: 1, title: 'Ruby on Rails', url: 'https://rubyonrails.org', snippet: 'Rails is a web framework.' },
            { id: 2, title: 'DHH', url: 'https://dhh.dk' }
          ] },
        { type: 'message', id: 'msg_1', role: 'assistant', status: 'completed',
          content: [{ type: 'output_text', text:, annotations: [] }] }
      ],
      usage: { input_tokens: 12, output_tokens: 7 }
    }
  end

  def event_stream(*events)
    body = events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join
    { body:, headers: { 'Content-Type' => 'text/event-stream' } }
  end

  def preset_chat(model)
    RubyLLM.chat(model:, provider: :perplexity, assume_model_exists: true).tap do |preset|
      preset.add_message(role: :user, content: 'Hello')
    end
  end

  it 'runs chat on the Agent API while embeddings keep their own protocol' do
    provider = chat.provider

    expect(provider.send(:resolve_protocol, nil, chat.model)).to eq(described_class)
    expect(provider.send(:resolve_protocol, nil, chat.model, operation: :embed))
      .to eq(RubyLLM::Providers::Perplexity::ChatCompletions)
  end

  it 'keeps Sonar Chat Completions available as an explicit protocol' do
    sonar = RubyLLM.chat(model: 'sonar', provider: :perplexity, protocol: :chat_completions)
    sonar.add_message(role: :user, content: 'Hello')

    expect(sonar.render).to include(model: 'sonar', messages: [{ role: 'user', content: 'Hello' }])
  end

  it 'sends a model id as the model, statelessly' do
    chat.add_message(role: :user, content: 'Hello')

    expect(chat.render).to include(model: model_for(:perplexity, :agent), store: false)
    expect(chat.render).not_to have_key(:preset)
  end

  it 'sends a preset in place of a model' do
    payload = preset_chat('wide-research').render

    expect(payload).to include(preset: 'wide-research')
    expect(payload).not_to have_key(:model)
  end

  it 'runs a retired Sonar model id as its recommended preset and warns' do
    allow(RubyLLM.deprecator).to receive(:warn)

    expect(preset_chat('sonar-pro').render).to include(preset: 'low')
    expect(RubyLLM.deprecator).to have_received(:warn).with(/sonar-pro now runs the low Agent API preset/)
  end

  it 'posts to the Agent endpoint, keeping configured gateway base paths' do
    expect(chat.provider.agent_url).to eq(url)
    ['https://gateway.test/perplexity', 'https://gateway.test/perplexity/v1/'].each do |base|
      context = RubyLLM.context { |config| config.perplexity_api_base = base }
      provider = RubyLLM::Providers::Perplexity.new(context.config)
      expect(provider.agent_url).to eq('https://gateway.test/perplexity/v1/agent')
    end
  end

  it 'turns search results into citations' do
    stub_request(:post, url).to_return_json(body: response_body)

    response = chat.ask('Who created Rails?')

    expect(response.content).to eq('Rails was created by David Heinemeier Hansson.[1]')
    expect(response.citations.map(&:to_h)).to eq(
      [{ url: 'https://rubyonrails.org', title: 'Ruby on Rails', cited_text: 'Rails is a web framework.',
         source_index: 0 },
       { url: 'https://dhh.dk', title: 'DHH', source_index: 1 }]
    )
  end

  it 'turns search results into citations while streaming' do
    stub_request(:post, url).to_return(
      event_stream({ type: 'response.output_text.delta', delta: 'Rails' },
                   { type: 'response.completed', response: response_body('Rails') })
    )

    response = chat.ask('Who created Rails?') { |_chunk| nil }

    expect(response.citations.map(&:url)).to eq(%w[https://rubyonrails.org https://dhh.dk])
  end

  it 'reports the cost Perplexity bills, including search fees' do
    body = response_body
    body[:usage][:cost] = { input_cost: 0.0001, output_cost: 0.0002, tool_calls_cost: 0.0025, total_cost: 0.0028 }
    stub_request(:post, url).to_return_json(body:)

    expect(chat.ask('Who created Rails?').cost.total).to eq(0.0028)
  end

  it 'counts cache writes apart from fresh input' do
    body = response_body
    body[:usage] = { input_tokens: 1494, output_tokens: 7,
                     input_tokens_details: { cache_creation_input_tokens: 32, cached_tokens: 1459 } }
    stub_request(:post, url).to_return_json(body:)

    expect(chat.ask('Who created Rails?').tokens).to have_attributes(input: 3, cache_read: 1459, cache_write: 32)
  end

  it 'replays a searched turn without the search results Perplexity rejects as input' do
    payloads = []
    stub_request(:post, url).with { |request| payloads << JSON.parse(request.body) }
                            .to_return_json(body: response_body)

    chat.ask('Who created Rails?')
    chat.ask('When?')

    expect(payloads.last['input'].map { |item| item['type'] || item['role'] }).to eq(%w[user message user])
    expect(payloads).to all(satisfy { |payload| !payload.key?('previous_response_id') })
  end

  it 'runs a streamed function call that arrives whole, without argument deltas' do
    call = { type: 'function_call', call_id: 'call_add', name: 'add', arguments: '{"left":1,"right":2}',
             status: 'completed' }
    answer = response_body('3').merge(output: [{ type: 'message', role: 'assistant',
                                                 content: [{ type: 'output_text', text: '3' }] }])
    stub_request(:post, url)
      .to_return(event_stream({ type: 'response.output_item.added', output_index: 0, item: call },
                              { type: 'response.output_item.done', output_index: 0, item: call },
                              { type: 'response.completed',
                                response: { model: 'openai/gpt-5-mini', status: 'completed', output: [call] } }))
      .then.to_return(event_stream({ type: 'response.output_text.delta', delta: '3' },
                                   { type: 'response.completed', response: answer }))
    arguments = []
    chat.with_tools(add_tool).before_tool_call { |tool_call| arguments << tool_call.arguments }

    response = chat.ask('Add 1 and 2.') { |_chunk| nil }

    expect(arguments).to eq([{ 'left' => 1, 'right' => 2 }])
    expect(response.content).to eq('3')
  end

  it 'does not run the web searches Perplexity streams as function calls' do
    search = { type: 'function_call', call_id: 'call_search', name: 'search_web',
               arguments: '{"queries":["rails creator"]}', status: 'completed' }
    results = response_body[:output].first
    stub_request(:post, url).to_return(
      event_stream({ type: 'response.output_item.added', output_index: 0, item: search },
                   { type: 'response.output_item.done', output_index: 0, item: results },
                   { type: 'response.output_text.delta', output_index: 1, delta: 'DHH' },
                   { type: 'response.completed', response: response_body('DHH') })
    )

    response = chat.ask('Who created Rails?') { |_chunk| nil }

    expect(response.tool_calls).to be_blank
    expect(response.content).to eq('DHH')
  end

  it 'rejects documents, which the Agent API does not accept' do
    pdf = File.expand_path('../../../fixtures/sample.pdf', __dir__)
    chat.add_message(role: :user, content: 'Summarize this.', attachments: [pdf])

    expect { chat.render }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
  end
end
