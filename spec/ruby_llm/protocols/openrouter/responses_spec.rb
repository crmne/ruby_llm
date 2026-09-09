# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::OpenRouter::Responses do
  let(:model) { model_for(:openrouter, :server_tools) }
  let(:context) { RubyLLM.context { |config| config.openrouter_api_key = 'test' } }
  let(:chat) { context.chat(model:, provider: :openrouter, protocol: :responses) }
  let(:protocol) { described_class.new(chat.provider, chat.model) }

  def completion
    {
      id: 'response-1', status: 'completed', model:,
      output: [{ type: 'openrouter:shell', id: 'shell-1', status: 'completed',
                 action: { commands: ['python3 -c "print(17*23)"'] },
                 output: [{ stdout: "391\n", stderr: '', outcome: { type: 'exit', exit_code: 0 } }] },
               { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: '391' }] }],
      usage: { input_tokens: 395, output_tokens: 50, input_tokens_details: { cached_tokens: 10 },
               cost: 0.00139125, server_tool_use_details: { tool_calls_executed: 1 } }
    }
  end

  it 'preserves hosted shell output and actual token and billing data through Responses' do
    request = stub_request(:post, 'https://openrouter.ai/api/v1/responses')
              .with { |req| JSON.parse(req.body)['tools'] == [{ 'type' => 'openrouter:shell' }] }
              .to_return_json(body: completion)
    message = chat.with_server_tools(:code_execution).ask('Calculate 17 times 23 with Python.')

    expect(message).to have_attributes(content: '391', finish_reason: :stop)
    expect(message.server_tool_calls.first.result.first['stdout']).to eq("391\n")
    expect(message.tokens).to have_attributes(input: 385, output: 50, cache_read: 10, reported_cost: 0.00139125)
    expect(message.tokens.server_tool_use).to eq('tool_calls_executed' => 1)
    expect(message.raw_content.first['id']).to eq('shell-1')
    expect(request).to have_been_requested.once
  end

  it 'keeps normal chat and individual operations on their existing adapters' do
    provider = chat.provider
    expect(provider.resolve_protocol(nil, nil).ancestors).to include(RubyLLM::Providers::OpenRouter::ChatCompletions)
    context.config.openrouter_protocol = :responses
    expect(provider.resolve_protocol(nil, nil)).to eq(described_class)
    expect(provider.resolve_protocol(nil, nil, operation: :transcribe).ancestors)
      .to include(RubyLLM::Providers::OpenRouter::ChatCompletions)
  end

  it 'rejects MCP without explicit approval-free execution before making a request' do
    [nil, 'always', { never: { tool_names: ['search'] } }].each do |approval|
      options = { name: 'docs', url: 'https://example.test/mcp' }
      options[:require_approval] = approval if approval
      expect { chat.with_server_tools(mcp: options).ask('Search documentation.') }
        .to raise_error(ArgumentError, /requires explicit require_approval/)
    end
    expect(a_request(:post, 'https://openrouter.ai/api/v1/responses')).not_to have_been_made
  end

  it 'retains only MCP data actually present in incomplete upstream stream events' do
    event = { 'type' => 'response.mcp_call_arguments.done', 'item_id' => 'mcp-1', 'arguments' => '{"query":"Ruby"}' }
    chunk = protocol.send(:build_chunk, event)
    expect(chunk.server_tool_calls.first)
      .to have_attributes(type: 'mcp_call', id: 'mcp-1', input: '{"query":"Ruby"}', name: nil, result: nil, raw: event)
    expect(chunk.tool_calls).to be_nil
  end

  it 'executes a hosted shell and returns its real output and billed usage', :live do
    message = RubyLLM.chat(model:, provider: :openrouter, protocol: :responses).with_max_output_tokens(700)
                     .with_server_tools(code_execution: { parameters: { engine: 'openrouter' } })
                     .ask('Use the hosted shell to run python3 -c "print(17*23)". Reply with the result only.')
    expect(message.content).to include('391')
    call = message.server_tool_calls.find { |tool| tool.type == 'openrouter:shell' }
    expect(call.result.first['stdout']).to include('391')
    expect(call.result.first.dig('outcome', 'exit_code')).to eq(0)
    expect(message.tokens.input).to be > 0
    expect(message.tokens.output).to be > 0
    expect(message.cost.total).to be > 0
  end

  it 'records remote MCP arguments without inventing omitted tool names or results', :live do
    chunks = []
    prompt = 'Use microsoft_docs_search to find Microsoft documentation about Ruby. Summarize in one sentence.'
    message = RubyLLM.chat(model:, provider: :openrouter, protocol: :responses).with_max_output_tokens(700)
                     .with_server_tools(mcp: { name: 'learn', url: 'https://learn.microsoft.com/api/mcp',
                                               allowed_tools: ['microsoft_docs_search'], require_approval: 'never' })
                     .ask(prompt) do |chunk|
      chunks << chunk
    end
    calls = chunks.flat_map(&:server_tool_calls).select { |call| call.type == 'mcp_call' }
    expect(calls).not_to be_empty
    expect(calls.first.input).to include('Ruby')
    expect(calls.first.name).to be_nil
    expect(calls.first.result).to be_nil
    expect(message.content).not_to be_empty
    expect(message.tokens.input).to be > 0
    expect(message.tokens.output).to be > 0
  end
end
