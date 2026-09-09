# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Approvals do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::Responses.allocate }
  let(:approval) do
    { 'type' => 'mcp_approval_request', 'id' => 'approval_1', 'server_label' => 'docs',
      'name' => 'search', 'arguments' => '{"query":"Ruby"}' }
  end
  let(:body) { { 'status' => 'completed', 'output' => [approval] } }

  def parse(body)
    protocol.send(:parse_completion_body, body, raw: instance_double(Faraday::Response, body:))
  end

  it 'exposes pending server approval as a tool call while preserving raw history' do
    message = parse(body)

    expect(message.tool_calls.fetch('approval_1'))
      .to have_attributes(id: 'approval_1', name: 'search', arguments: { 'query' => 'Ruby' }, remote?: true)
    expect(message.raw_content).to eq([approval])
    expect(message.server_tool_calls.first.raw).to eq(approval)
  end

  it 'accepts arguments already decoded by the provider' do
    message = parse('status' => 'completed', 'output' => [approval.merge('arguments' => { 'query' => 'Ruby' })])

    expect(message.tool_calls.fetch('approval_1').arguments).to eq('query' => 'Ruby')
  end

  it 'identifies remote approvals independently of their provider label' do
    message = parse('status' => 'completed', 'output' => [approval.except('server_label')])

    expect(message.tool_calls.fetch('approval_1')).to be_remote
  end

  it 'maps portable MCP names while retaining provider options' do
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
                  .with_server_tools(mcp: { name: 'docs', url: 'https://example.test/mcp', require_approval: 'always' })

    expect(chat.render[:tools]).to include(type: 'mcp', server_label: 'docs',
                                           server_url: 'https://example.test/mcp', require_approval: 'always')
  end

  it 'does not turn completed remote executions into pending local tools' do
    call = approval.merge('type' => 'mcp_call', 'id' => 'remote_1', 'output' => 'Ruby docs')
    message = parse('status' => 'completed', 'output' => [call])

    expect(message.tool_calls).to be_nil
    expect(message.server_tool_calls.first.result).to eq('Ruby docs')
  end

  [true, false].each do |approved|
    it "replays the #{approved ? 'approval' : 'denial'} without a local function output" do
      request = parse(body).tool_calls.fetch('approval_1')
      response = protocol.tool_approval_response(request, approved:)

      expect(response).to have_attributes(role: :tool, tool_call_id: 'approval_1')
      expected = { type: 'mcp_approval_response', approval_request_id: 'approval_1', approve: approved }
      expect(protocol.send(:format_tool_items, response)).to eq([expected])
    end
  end

  it 'preserves a streamed approval exactly once across repeated final events' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    event = { 'type' => 'response.completed', 'response' => body }
    2.times { accumulator.add(protocol.send(:build_chunk, event)) }
    message = accumulator.to_message(instance_double(Faraday::Response, body:))

    expect(message.server_tool_calls.size).to eq(1)
    expect(message.tool_calls.keys).to eq(['approval_1'])
    expect(message.tool_calls.fetch('approval_1')).to have_attributes(remote?: true, arguments: { 'query' => 'Ruby' })
  end
end
