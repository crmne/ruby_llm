# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Mistral::Conversations do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:mistral), provider: :mistral, protocol: :conversations) }
  let(:protocol) { RubyLLM::Providers::Mistral::Conversations.new(chat.provider, chat.model) }
  let(:confirmation_tool) do
    { web_search: { tool_configuration: { requires_confirmation: ['web_search'] } } }
  end
  let(:pending) do
    { 'object' => 'conversation.response', 'conversation_id' => 'conv_test', 'outputs' => [
      { 'type' => 'function.call', 'id' => 'fc_test', 'tool_call_id' => 'search_test', 'name' => 'web_search',
        'arguments' => '{"query":"Ruby"}', 'confirmation_status' => 'pending' }
    ], 'usage' => { 'prompt_tokens' => 20, 'completion_tokens' => 5 } }
  end

  it 'keeps Chat Completions as the default and registers the explicit conversations protocol' do
    expect(RubyLLM::Providers::Mistral.default_protocol).to eq(:chat_completions)
    expect(chat.ask_later('Hello').render).to include(store: false,
                                                      inputs: [{
                                                        type: 'message.input', role: 'user', content: 'Hello'
                                                      }])
  end

  it 'renders instructions, JSON Schema, limits, and temperature in their documented fields' do
    schema = { type: 'object', properties: { count: { type: 'integer' } }, required: ['count'] }
    payload = chat.with_instructions('Be concise').with_schema(schema).with_temperature(0.2)
                  .with_max_output_tokens(50).ask_later('Count').render
    expect(payload[:instructions]).to eq('Be concise')
    expect(payload[:completion_args]).to include(temperature: 0.2, max_tokens: 50)
    expect(payload.dig(:completion_args, :response_format, :type)).to eq('json_schema')
  end

  it 'deduplicates the shared web search and fetch tool while rendering every supported alias' do
    payload = chat.with_server_tools(:web_search, :web_fetch, :code_execution, :image_generation,
                                     file_search: { library_ids: ['library_test'] }, mcp: { connector_id: 'docs' })
                  .ask_later('Hello').render
    expect(payload[:tools].map do |tool|
      tool['type']
    end).to eq(%w[web_search code_interpreter image_generation document_library connector])
  end

  it 'rejects hosted confirmations before sending a request' do
    chat.with_server_tools(**confirmation_tool).ask_later('Find Ruby documentation')
    expect { chat.render }.to raise_error(ArgumentError, /require provider conversation storage/)
  end

  it 'rejects unexpected pending hosted confirmations without executing them as Ruby tools' do
    expect { protocol.send(:parse_completion_body, pending, raw: nil) }
      .to raise_error(RubyLLM::Error, /requires provider conversation storage/)
  end

  it 'replays edited history after serialization without continuing a remote conversation' do
    chat.ask_later('Remember violet')
    completed = pending.merge('outputs' => [{ 'type' => 'message.output', 'content' => 'OK' }])
    chat.add_message(protocol.send(:parse_completion_body, completed, raw: nil))
    restored = RubyLLM.chat(model: chat.model.id, provider: :mistral, protocol: :conversations)
    restored.messages = JSON.parse(JSON.generate(chat.messages.map(&:to_h))).map do |message|
      message.transform_keys(&:to_sym)
    end
    restored.messages.first.content.replace('Remember orange')
    restored.with_instructions('Be concise').ask_later('What color?')
    payload = restored.render
    expect(payload).to include(model: chat.model.id, store: false, instructions: 'Be concise')
    expect(payload[:inputs]).to include(include(content: 'Remember orange'), include(content: 'What color?'))
    expect(payload[:inputs]).to include('type' => 'message.output', 'content' => 'OK')
    expect(protocol.send(:completion_url)).to eq('conversations')
    expect(JSON.generate(payload)).not_to include('conv_test', 'Remember violet')
  end

  it 'keeps local function calls separate from completed hosted executions' do
    local = pending['outputs'].first.except('confirmation_status')
    output = %w[allowed denied].map do |status|
      pending['outputs'].first.merge('confirmation_status' => status, 'tool_call_id' => status)
    end
    message = protocol.send(:parse_completion_body, pending.merge('outputs' => output + [local]), raw: nil)
    expect(message.tool_calls.keys).to eq(['search_test'])
    expect(message.tool_calls.values).to all(have_attributes(remote?: false))
    expect(message.server_tool_calls.map(&:id)).to eq(%w[fc_test fc_test])
  end

  it 'parses hosted steps, citation markers, and connector input tokens without inflating output' do
    data = { 'outputs' => [
      { 'type' => 'tool.execution', 'name' => 'web_search', 'id' => 'search', 'arguments' => '{}',
        'info' => { 'result' => 'Ruby docs' } },
      { 'type' => 'message.output', 'content' => [
        { 'type' => 'text', 'text' => 'Ruby docs' },
        { 'type' => 'tool_reference', 'url' => 'https://www.ruby-lang.org', 'title' => 'Ruby' }
      ] }
    ], 'usage' => { 'prompt_tokens' => 20, 'completion_tokens' => 5, 'connector_tokens' => 100,
                    'total_tokens' => 125, 'connectors' => { 'web_search' => 1 } } }
    message = protocol.send(:parse_completion_body, data, raw: nil)
    expect(message.content).to eq('Ruby docs')
    expect(message.tokens).to have_attributes(input: 120, output: 5)
    expect(message.citations.first).to have_attributes(title: 'Ruby', start_index: 9, end_index: 9)
    expect(message.server_tool_calls.first).to have_attributes(name: 'web_search', result: { 'result' => 'Ruby docs' })
    expect(message.raw_content).to eq(data['outputs'])
  end

  it 'keeps generated provider files as typed attachments' do
    data = { 'outputs' => [{ 'type' => 'message.output', 'content' => [
      { 'type' => 'tool_file', 'tool' => 'image_generation', 'file_id' => 'image_test',
        'file_name' => 'circle', 'file_type' => 'png' }
    ] }] }
    message = protocol.send(:parse_completion_body, data, raw: nil)
    expect(message.attachments.first.source).to have_attributes(id: 'image_test', provider: 'mistral',
                                                                mime_type: 'image/png')
  end

  it 'replays actual hosted results without modifying the saved provider history' do
    entries = [
      { 'type' => 'tool.execution', 'id' => 'first', 'function' => 'lookup', 'arguments' => '{}',
        'info' => { 'result' => false } },
      { 'type' => 'tool.execution', 'id' => 'second', 'function' => 'lookup', 'arguments' => '{}',
        'info' => { 'result' => { 'answer' => 42 } } },
      { 'type' => 'message.output', 'content' => [
        { 'type' => 'tool_reference', 'title' => 'Ruby', 'url' => 'https://www.ruby-lang.org' }
      ] }
    ]
    message = RubyLLM::Message.new(role: :assistant, content: nil, raw_content: entries)
    rendered = protocol.send(:format_entries, [message])
    expect(rendered.filter_map { |entry| entry['result'] if entry['type'] == 'function.result' })
      .to eq(['false', '{"answer":42}'])
    expect(rendered.first['tool_call_id']).not_to eq(rendered[2]['tool_call_id'])
    expect(rendered.last['content']).to eq([{ 'type' => 'text', 'text' => '[Ruby](https://www.ruby-lang.org)' }])
    expect(message.raw_content).to eq(entries)
    expect(entries.first['type']).to eq('tool.execution')
  end

  it 'rejects truncated conversation streams and reports provider stream errors' do
    allow(protocol).to receive(:stream_events).and_return(instance_double(Faraday::Response))
    expect { protocol.send(:stream_response, {}) { |_chunk| nil } }
      .to raise_error(RubyLLM::Error, /ended before completion/)
    expect { protocol.send(:build_chunk, { 'type' => 'conversation.response.error', 'message' => 'Tool failed' }) }
      .to raise_error(RubyLLM::Error, 'Tool failed')
  end

  it 'accumulates tool arguments, text, and final usage from Conversations events' do
    events = [
      { 'type' => 'conversation.response.started', 'conversation_id' => 'conv_test' },
      { 'type' => 'tool.execution.started', 'output_index' => 0, 'id' => 'exec', 'name' => 'code_interpreter',
        'arguments' => '' },
      { 'type' => 'tool.execution.delta', 'output_index' => 0, 'arguments' => '{"code":"1+1"}' },
      { 'type' => 'tool.execution.done', 'output_index' => 0, 'info' => { 'result' => '2' } },
      { 'type' => 'message.output.delta', 'output_index' => 1, 'content_index' => 0, 'id' => 'msg', 'content' => 'Tw' },
      { 'type' => 'message.output.delta', 'output_index' => 1, 'content_index' => 0, 'id' => 'msg', 'content' => 'o' },
      { 'type' => 'conversation.response.done',
        'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 2, 'connector_tokens' => 1 } }
    ]
    chunks = events.map { |event| protocol.send(:build_chunk, event) }
    expect(chunks.filter_map(&:content).join).to eq('Two')
    expect(chunks.last.tokens).to have_attributes(input: 11, output: 2)
    expect(chunks.last.server_tool_calls.first.input).to eq('{"code":"1+1"}')
    expect(chunks.last.raw_content.last['content']).to eq([{ 'type' => 'text', 'text' => 'Two' }])
  end
end
