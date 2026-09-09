# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Interactions do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:gemini, :mcp), provider: :gemini, protocol: :interactions) }
  let(:protocol) { described_class.new(chat.provider, chat.model) }
  let(:tool) do
    Class.new(RubyLLM::Tool) do
      description 'Multiply two numbers'
      parameter :left, type: :integer
      parameter :right, type: :integer
      define_method(:name) { 'multiply' }
      define_method(:execute) { |left:, right:| left * right }
    end
  end
  let(:steps) do
    [
      { 'type' => 'mcp_server_tool_call', 'id' => 'remote1', 'name' => 'docs:search',
        'server_name' => 'docs', 'arguments' => { 'query' => 'Ruby' }, 'signature' => 'call-signature' },
      { 'type' => 'mcp_server_tool_result', 'call_id' => 'remote1', 'name' => 'docs:search',
        'server_name' => 'docs', 'result' => 'Ruby documentation', 'signature' => 'result-signature' },
      { 'type' => 'thought', 'signature' => 'thought-signature' },
      { 'type' => 'model_output', 'content' => [{ 'type' => 'text', 'text' => 'Ruby docs.' }] }
    ]
  end
  let(:body) do
    { 'object' => 'interaction', 'id' => 'interaction1', 'status' => 'completed', 'model' => chat.model.id,
      'steps' => steps, 'usage' => { 'total_input_tokens' => 20, 'total_tool_use_tokens' => 30,
                                     'total_output_tokens' => 5, 'total_thought_tokens' => 10,
                                     'total_cached_tokens' => 4 } }
  end

  it 'keeps generateContent as the default and renders the opt-in protocol through Chat' do
    expect(RubyLLM::Providers::Gemini.default_protocol).to eq(:gemini)
    payload = chat.with_instructions('Be concise').with_tools(tool).with_tool_options(choice: :required)
                  .with_server_tools(mcp: { name: 'docs', url: 'https://example.com/mcp' })
                  .with_max_output_tokens(50).ask_later('Multiply').render
    expect(payload).to include(store: false, system_instruction: 'Be concise',
                               input: [{ type: 'user_input', content: [{ type: 'text', text: 'Multiply' }] }])
    expect(payload[:generation_config]).to include(max_output_tokens: 50, tool_choice: 'any')
    expect(payload[:tools].first).to include(type: 'function', name: 'multiply')
    expect(payload[:tools].last).to include(type: 'mcp_server', name: 'docs', url: 'https://example.com/mcp')
  end

  it 'normalizes complete MCP output and preserves every signed step for stateless replay' do
    message = protocol.send(:parse_completion_body, body, raw: nil)
    expect(message.content).to eq('Ruby docs.')
    expect(message).not_to be_tool_call
    expect(message.server_tool_calls.map(&:type)).to eq(%w[mcp_server_tool_call mcp_server_tool_result])
    expect(message.server_tool_calls.last.result).to eq('Ruby documentation')
    expect(message.tokens).to have_attributes(input: 46, output: 15, thinking: 10, cache_read: 4)
    chat.messages = [JSON.parse(JSON.generate(message.to_h)).transform_keys(&:to_sym)]
    chat.ask_later('Continue')
    replay = chat.render[:input].first(steps.size)
    expect(replay.first(2)).to eq(steps.first(2).map { |step| step.except('signature') })
    expect(replay[2]['signature']).to eq('thought-signature')
    expect(message.raw_content.dig('response', 'steps')).to eq(steps)
  end

  it 'keeps local function calls separate from remote executions' do
    data = body.merge('status' => 'requires_action', 'steps' => steps + [
      { 'type' => 'function_call', 'id' => 'local1', 'name' => 'multiply',
        'arguments' => { 'left' => 2, 'right' => 3 }, 'signature' => 'local-signature' }
    ])
    message = protocol.send(:parse_completion_body, data, raw: nil)
    expect(message.tool_calls.keys).to eq(['local1'])
    expect(message.tool_calls['local1']).to have_attributes(remote?: false, thought_signature: 'local-signature')
  end

  it 'includes the function name with a local result even though the upstream schema marks it optional' do
    chat.with_tools(tool)
    chat.add_message(role: :assistant, content: nil, tool_calls: {
                       'local1' => RubyLLM::ToolCall.new(id: 'local1', name: 'multiply', arguments: {})
                     })
    chat.add_message(role: :tool, content: '91', tool_call_id: 'local1')
    expect(chat.render[:input].last).to include(type: 'function_result', call_id: 'local1', name: 'multiply')
  end

  it 'replays edited history and signed results after serialization without a remote cursor' do
    chat.ask_later('Remember violet')
    chat.add_message(protocol.send(:parse_completion_body, body, raw: nil))
    restored = RubyLLM.chat(model: chat.model.id, provider: :gemini, protocol: :interactions)
    restored.messages = JSON.parse(JSON.generate(chat.messages.map(&:to_h))).map do |entry|
      entry.transform_keys(&:to_sym)
    end
    restored.messages.first.content.replace('Remember orange')
    payload = restored.ask_later('What color?').render
    expect(payload).to include(store: false)
    expect(payload).not_to have_key(:previous_interaction_id)
    expect(payload[:input].first).to eq(type: 'user_input', content: [{ type: 'text', text: 'Remember orange' }])
    expect(payload[:input]).to include(steps.first.except('signature'), steps[2])
    expect(payload[:input].last).to eq(type: 'user_input', content: [{ type: 'text', text: 'What color?' }])
  end

  it 'replays a local function call and its named result without provider storage' do
    data = body.merge('status' => 'requires_action', 'steps' => [
                        { 'type' => 'function_call', 'id' => 'local1', 'name' => 'multiply',
                          'arguments' => { 'left' => 13, 'right' => 7 } }
                      ])
    chat.with_tools(tool).ask_later('Multiply')
    chat.add_message(protocol.send(:parse_completion_body, data, raw: nil))
    chat.run_tools
    payload = chat.render
    expect(payload).to include(store: false)
    expect(payload).not_to have_key(:previous_interaction_id)
    expect(payload[:input]).to include(data['steps'].first)
    expect(payload[:input].last).to eq(type: 'function_result', call_id: 'local1', name: 'multiply',
                                       result: [{ type: 'text', text: '91' }])
  end

  it 'renders JSON Schema and specific tool choice in the documented fields' do
    schema = { type: 'object', properties: { answer: { type: 'integer' } }, required: ['answer'] }
    payload = chat.with_schema(schema).with_tools(tool).with_tool_options(choice: 'multiply')
                  .ask_later('Multiply').render
    expect(payload[:response_format]).to include(type: 'text', mime_type: 'application/json')
    expect(payload[:response_format][:schema]).to include(type: 'object')
    expect(payload.dig(:generation_config, :tool_choice)).to eq(allowed_tools: { mode: 'any', tools: ['multiply'] })
  end

  it 'converts citation byte offsets to characters across multiple output parts' do
    data = body.merge('steps' => [{ 'type' => 'model_output', 'content' => [
                        { 'type' => 'text', 'text' => 'First. ' },
                        { 'type' => 'text', 'text' => 'Café Ruby', 'annotations' => [
                          { 'type' => 'url_citation', 'url' => 'https://www.ruby-lang.org', 'start_index' => 6,
                            'end_index' => 10 },
                          { 'type' => 'file_citation', 'file_name' => 'Manual',
                            'document_uri' => 'gs://docs/manual.pdf',
                            'page_number' => 2, 'start_index' => 0, 'end_index' => 5 }
                        ] }
                      ] }])
    message = protocol.send(:parse_completion_body, data, raw: nil)
    expect(message.citations.first).to have_attributes(start_index: 12, end_index: 16, text: 'Ruby')
    expect(message.citations.last).to have_attributes(title: 'Manual', start_page: 2, end_page: 2, text: 'Café')
  end

  it 'separates thinking effort from summary display and rejects an unsupported off control' do
    %i[minimal low medium high].each do |effort|
      config = chat.with_thinking(effort: effort, display: :summarized).ask_later('Think').render[:generation_config]
      expect(config).to include(thinking_level: effort.to_s, thinking_summaries: 'auto')
    end
    expect(chat.with_thinking(effort: :low, display: :omitted).render[:generation_config])
      .to include(thinking_level: 'low', thinking_summaries: 'none')
    [RubyLLM::Thinking::Config.new(enabled: false), RubyLLM::Thinking::Config.new(effort: :none),
     RubyLLM::Thinking::Config.new(budget: 0)].each do |config|
      expect { protocol.send(:render_interaction_thinking, config) }.to raise_error(ArgumentError, /thinking-off/)
    end
    expect { chat.with_thinking(effort: :xhigh).render }.to raise_error(ArgumentError, /effort must be/)
    expect { chat.with_thinking(budget: 1024).render }.to raise_error(ArgumentError, /not a token budget/)
    expect { chat.with_thinking(display: :full).render }.to raise_error(ArgumentError, /display must be/)
  end

  it 'renders image and PDF attachments as content without changing normal file handling' do
    chat.ask_later('Read', with: ['spec/fixtures/ruby.png', 'spec/fixtures/sample.pdf'])
    parts = chat.render[:input].first[:content]
    expect(parts.map { |part| part[:type] }).to eq(%w[text image document])
    expect(parts.last).to include(mime_type: 'application/pdf', data: a_string_starting_with('JVBER'))
  end

  it 'accumulates streamed MCP steps and never yields remote result text as assistant text' do
    events = [{ 'event_type' => 'interaction.created', 'interaction' => body.except('steps', 'usage') }]
    steps.each_with_index do |step, index|
      events << { 'event_type' => 'step.start', 'index' => index, 'step' => step.except('content', 'result') }
      delta = step['type'] == 'model_output' ? { 'type' => 'text', 'text' => 'Ruby docs.' } : step
      events << { 'event_type' => 'step.delta', 'index' => index, 'delta' => delta }
    end
    events << { 'event_type' => 'interaction.completed', 'interaction' => body.except('steps') }
    allow(protocol).to receive(:stream_events).and_wrap_original do |_method, *_args, &block|
      events.each(&block)
      instance_double(Faraday::Response)
    end
    chunks = []
    message = protocol.send(:stream_response, {}) { |chunk| chunks << chunk }
    expect(chunks.filter_map(&:content).join).to eq('Ruby docs.')
    expect(message.server_tool_calls.last.result).to eq('Ruby documentation')
    expect(message.raw_content.dig('response', 'steps')).to eq(steps)
    expect(chunks.last.tokens).to have_attributes(input: 46, output: 15)
  end

  it 'rejects failed or truncated streams and unsupported required actions' do
    allow(protocol).to receive(:stream_events).and_return(instance_double(Faraday::Response))
    expect { protocol.send(:stream_response, {}) { |_chunk| nil } }.to raise_error(RubyLLM::Error, /ended before/)
    expect { protocol.send(:build_chunk, { 'event_type' => 'error', 'error' => { 'message' => 'Failed' } }) }
      .to raise_error(RubyLLM::Error, 'Failed')
    expect { protocol.send(:parse_completion_body, body.merge('status' => 'requires_action'), raw: nil) }
      .to raise_error(RubyLLM::Error, /unsupported action/)
  end

  it 'accumulates local function argument deltas after an empty object in the initial step' do
    events = [
      { 'event_type' => 'step.start', 'index' => 0,
        'step' => { 'type' => 'function_call', 'id' => 'local1', 'name' => 'multiply', 'arguments' => {} } },
      { 'event_type' => 'step.delta', 'index' => 0,
        'delta' => { 'type' => 'arguments_delta', 'arguments' => '{"left":17,' } },
      { 'event_type' => 'step.delta', 'index' => 0,
        'delta' => { 'type' => 'arguments_delta', 'arguments' => '"right":19}' } },
      { 'event_type' => 'interaction.completed',
        'interaction' => body.except('steps').merge('status' => 'requires_action') }
    ]
    allow(protocol).to receive(:stream_events) do |*_args, &block|
      events.each(&block)
      instance_double(Faraday::Response)
    end
    message = protocol.send(:stream_response, {}) { |_chunk| nil }
    expect(message.tool_calls['local1'].arguments).to eq('left' => 17, 'right' => 19)
    chat.add_message(message)
    expect(chat.render[:input].last['arguments']).to eq('left' => 17, 'right' => 19)
  end

  it 'uses Vertex AI Search retrieval for its named file-search alias' do
    vertex = RubyLLM.chat(model: model_for(:vertexai), provider: :vertexai)
    allow(vertex.provider).to receive(:headers).and_return({})
    payload = vertex.with_server_tools(file_search: { datastore: 'projects/test/locations/global/dataStores/docs' })
                    .ask_later('Find the manual').render
    expect(payload[:tools]).to eq([{ retrieval: {
                                    vertexAiSearch: { datastore: 'projects/test/locations/global/dataStores/docs' }
                                  } }])
  end

  it 'executes a remote MCP tool and replays its signed results through stateless chat', :live do
    chat.with_server_tools(mcp: { name: 'microsoft_learn', url: 'https://learn.microsoft.com/api/mcp' })
    message = chat.ask('Use the Microsoft Learn MCP search tool to find the Azure Functions overview. Reply briefly.')
    expect(message.server_tool_calls).to include(have_attributes(type: 'mcp_server_tool_call'))
    expect(message.server_tool_calls).to include(have_attributes(type: 'mcp_server_tool_result'))
    expect(message).not_to be_tool_call
    expect(message.content).to match(/functions/i)
    expect(chat.ask('What Microsoft service did you look up? Answer using the previous results.').content)
      .to match(/azure functions/i)
  end

  it 'streams remote MCP results and preserves the complete signed history', :live do
    chunks = []
    chat.with_server_tools(mcp: { name: 'microsoft_learn', url: 'https://learn.microsoft.com/api/mcp' })
    prompt = 'Use the Microsoft Learn MCP search tool to find the Azure Functions overview. Reply briefly.'
    message = chat.ask(prompt) do |chunk|
      chunks << chunk
    end
    expect(chunks.filter_map(&:content).join).to eq(message.content)
    expect(message.server_tool_calls).to include(have_attributes(type: 'mcp_server_tool_result'))
    expect(message.tokens.input).to be_positive
    expect(message.raw_content.dig('response', 'steps')).to include(include('signature'))
  end

  it 'executes local tools and returns JSON Schema output through Interactions', :live do
    schema = { type: 'object', properties: { answer: { type: 'integer' } }, required: ['answer'] }
    message = chat.with_tools(tool).with_schema(schema)
                  .ask('Use multiply to calculate 13 times 7 and return the answer.')
    expect(message.parsed).to eq('answer' => 91)
    expect(chat.messages.select(&:tool_result?).map(&:content)).to include('91')
  end

  it 'streams local function arguments and continues with the actual tool result', :live do
    response = chat.with_tools(tool).ask('Use multiply to calculate 17 times 19. State the result.') { |_chunk| nil }
    expect(response.content).to include('323')
    expect(chat.messages.select(&:tool_result?).map(&:content)).to include('323')
  end
end
