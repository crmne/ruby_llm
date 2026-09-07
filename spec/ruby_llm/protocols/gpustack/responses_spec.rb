# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::GPUStack::Responses do
  let(:model) { model_for(:gpustack) }
  let(:context) do
    RubyLLM.context do |config|
      config.gpustack_api_base = 'https://gpu.example.test/cluster/model/proxy/42/v1'
      config.gpustack_api_key = 'isolated-key'
    end
  end
  let(:chat) { context.chat(model:, provider: :gpustack, protocol: :responses) }
  let(:tool) { { name: 'code_interpreter', require_approval: 'never' } }
  let(:call) do
    { type: 'mcp_call', id: 'mcp_1', name: 'python', server_label: 'python',
      status: 'completed', arguments: '{"code":"print(2+2)"}', output: '4' }
  end

  def completion
    { model:, status: 'completed',
      output: [call, { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: '4' }] }],
      usage: { input_tokens: 20, output_tokens: 5, input_tokens_details: { cached_tokens: 4 } } }
  end

  it 'sends configured MCP labels and preserves complete calls, usage, and multi-turn replay' do
    request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/v1/responses')
              .with(headers: { 'Authorization' => 'Bearer isolated-key' }) do |req|
      JSON.parse(req.body)['tools'] == [{ 'type' => 'mcp', 'server_label' => 'code_interpreter',
                                          'require_approval' => 'never' }]
    end.to_return_json(body: completion)

    result = chat.with_server_tools(mcp: tool).ask('Calculate 2+2.')

    expect(result.server_tool_calls.first).to have_attributes(name: 'python', result: '4', id: 'mcp_1')
    expect(result.tokens).to have_attributes(input: 16, cache_read: 4, output: 5)
    expect(result).to have_attributes(content: '4', finish_reason: :stop)
    second = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/v1/responses').with do |req|
      input = JSON.parse(req.body)['input']
      input.include?('type' => 'function_call', 'call_id' => 'mcp_1', 'name' => 'python',
                     'arguments' => '{"code":"print(2+2)"}') &&
        input.include?('type' => 'function_call_output', 'call_id' => 'mcp_1', 'output' => '4') &&
        input.none? { |item| item['type'] == 'mcp_call' }
    end.to_return_json(body: completion)
    chat.ask('Repeat the answer.')
    expect(result.raw_content.first).to eq(JSON.parse(call.to_json))
    expect(second).to have_been_requested.once
    expect(request).to have_been_requested.twice
  end

  it 'retains incomplete Harmony tool records without inventing results or replaying unsupported item types' do
    raw = [{ 'type' => 'web_search_call', 'id' => 'ws_1', 'status' => 'completed',
             'action' => { 'type' => 'search', 'query' => 'cursor:Ruby' } },
           { 'type' => 'mcp_call', 'name' => 'exec', 'id' => 'mcp_2', 'arguments' => '{}', 'output' => nil }]
    message = RubyLLM::Message.new(role: :assistant, content: 'Ruby', raw_content: raw)
    protocol = described_class.new(chat.provider, chat.model)

    rendered = protocol.format_assistant_items(message)

    expect(rendered.map { |item| item[:role] }).to eq(%w[assistant assistant])
    expect(rendered.map { |item| JSON.parse(item[:content].first[:text]) }).to eq(raw)
    expect(message.raw_content).to eq(raw)
    parsed = protocol.send(:parse_completion_body, { 'output' => raw }, raw: nil)
    expect(parsed.server_tool_calls.map(&:result)).to eq([nil, nil])
  end

  it 'reads actual Harmony reasoning content when the provider has no summary' do
    body = { 'output' => [{ 'type' => 'reasoning', 'summary' => [],
                            'content' => [{ 'type' => 'reasoning_text', 'text' => 'I can calculate this.' }] }] }
    protocol = described_class.new(chat.provider, chat.model)

    expect(protocol.send(:parse_completion_body, body, raw: nil).thinking.text).to eq('I can calculate this.')
  end

  it 'passes documented browser subtool filters to the configured server' do
    request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/v1/responses')
              .with do |req|
      JSON.parse(req.body)['tools'].first == { 'type' => 'mcp', 'server_label' => 'web_search_preview',
                                               'allowed_tools' => ['search'], 'require_approval' => 'never' }
    end.to_return_json(body: completion)

    chat.with_server_tools(mcp: { name: 'web_search_preview', allowed_tools: ['search'], require_approval: 'never' })
        .ask('Search for Ruby.')
    expect(request).to have_been_requested.once
  end

  it 'maps portable server tools to only their configured vLLM namespace and subtools' do
    expected = {
      web_search: { 'server_label' => 'web_search_preview', 'allowed_tools' => ['search'] },
      web_fetch: { 'server_label' => 'web_search_preview', 'allowed_tools' => ['open'] },
      code_execution: { 'server_label' => 'code_interpreter' }
    }
    expected.each do |name, settings|
      request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/v1/responses').with do |req|
        JSON.parse(req.body)['tools'] == [{ 'type' => 'mcp', 'require_approval' => 'never', **settings }]
      end.to_return_json(body: completion)

      response = chat.with_server_tools(nil).with_server_tools(**{ name => { require_approval: 'never' } })
                     .ask('Use the enabled tool.')

      expect(response.server_tool_calls.first.result).to eq('4')
      expect(request).to have_been_requested.once
    end
  end

  it 'combines search and fetch filters so vLLM cannot overwrite one with the other' do
    request = stub_request(:post, 'https://gpu.example.test/cluster/model/proxy/42/v1/responses').with do |req|
      JSON.parse(req.body)['tools'] == [{ 'type' => 'mcp', 'server_label' => 'web_search_preview',
                                          'allowed_tools' => %w[search open], 'require_approval' => 'never' }]
    end.to_return_json(body: completion)

    chat.with_server_tools(web_search: { require_approval: 'never' }, web_fetch: { require_approval: 'never' })
        .ask('Search for the Ruby documentation and read the result.')

    expect(request).to have_been_requested.once
  end

  it 'rejects alias options that would broaden or change the requested operation' do
    %i[web_search web_fetch code_execution].each do |name|
      [{}, { require_approval: 'always' }, { require_approval: 'never', allowed_tools: ['*'] },
       { require_approval: 'never', url: 'https://example.test/mcp' },
       { require_approval: 'never', name: 'container' }].each do |options|
        expect { chat.with_server_tools(nil).with_server_tools(**{ name => options }).ask('Use the tool.') }
          .to raise_error(ArgumentError, /GPUStack/)
      end
    end
    expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
  end

  it 'rejects duplicate server settings that cannot preserve the explicit filters' do
    settings = [{ allowed_tools: nil }, { allowed_tools: ['*'] }, { allowed_tools: { tool_names: ['open'] } },
                { allowed_tools: ['open'], server_description: 'A different browser' }]
    settings.each do |options|
      mcp = { name: 'web_search_preview', require_approval: 'never' }.merge(options)
      expect do
        chat.with_server_tools(nil).with_server_tools(web_search: { require_approval: 'never' }, mcp:).ask('Search.')
      end.to raise_error(ArgumentError, /one entry with explicit tool names/)
    end
    expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
  end

  it 'rejects approval modes, per-request servers, and ignored read-only filters before HTTP' do
    invalid = [tool.except(:require_approval), tool.merge(require_approval: 'always'),
               tool.merge(url: 'https://example.test/mcp'), tool.merge(connector_id: 'connector'),
               tool.merge(allowed_tools: { read_only: true }), tool.merge(name: 'unknown')]
    invalid.each do |options|
      expect { chat.with_server_tools(nil).with_server_tools(mcp: options).ask('Calculate.') }
        .to raise_error(ArgumentError, /GPUStack|vLLM/)
    end
    expect(a_request(:post, /gpu.example.test/)).not_to have_been_made
  end

  it 'requires explicit execution consent and keeps ordinary chat on Chat Completions' do
    expect { chat.with_server_tools(:web_search).ask('Search.') }
      .to raise_error(ArgumentError, /explicit require_approval/)
    expect(chat.provider.resolve_protocol(nil, chat.model)).to eq(RubyLLM::Providers::GPUStack::ChatCompletions)
    context.config.gpustack_protocol = :responses
    expect(chat.provider.resolve_protocol(nil, chat.model)).to eq(described_class)
    expect(chat.provider.resolve_protocol(nil, chat.model, operation: :transcribe))
      .to eq(RubyLLM::Providers::GPUStack::ChatCompletions)
  end
end
