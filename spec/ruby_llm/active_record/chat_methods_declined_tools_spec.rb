# frozen_string_literal: true

require 'rails_helper'
require 'socket'
require 'timeout'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:requests) { [] }

  let(:refund) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'IssueRefund'

      description 'Refunds an order'
      requires_approval
      define_method(:execute) { |order_id:| "Refunded #{order_id}" }
    end
  end

  let(:files_class) do
    command = [RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)]
    Class.new(RubyLLM::MCP) do
      def self.name = 'Files'

      command(*command)
      requires_approval :add
    end
  end

  let(:refunds_agent) do
    tool = refund
    Class.new(RubyLLM::Agent) do
      chat_class Chat
      tools tool
    end
  end

  let(:plain_agent) { Class.new(RubyLLM::Agent) { chat_class Chat } }

  def refund_call
    RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'issue_refund',
                          arguments: { 'order_id' => '42' })
  end

  def done = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def answered(record)
    seen = requests
    allow(record.to_llm.provider).to receive(:complete) do |messages, **|
      seen << messages.to_a
      done
    end
    record
  end

  def paused(call, chat: Chat.create!(model: model_for(:openai)), tools: [refund], mcp: nil)
    chat.with_tools(*tools)
    chat.with_mcp(mcp) if mcp
    chat.add_message(role: :user, content: 'Refund order 42')
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
    answered(chat).complete
    expect(Chat.find(chat.id).pending_questions.map(&:id)).to eq([call.id])
    requests.clear
    chat
  end

  def resumed(record)
    Timeout.timeout(10) { answered(record).complete }
  end

  def result_of(tool_call)
    RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: tool_call.id).result&.content
  end

  {
    'no note' => [[], '{"error":"The user denied the issue_refund tool call."}'],
    'a String note' => [['The order shipped already'], '{"error":"The order shipped already"}'],
    'a Hash' => [[{ error: 'Denied', reason: 'Wrong account' }], '{"error":"Denied","reason":"Wrong account"}']
  }.each do |described, (note, result)|
    it "refuses a call declined with #{described} once the chat no longer offers its tool, and asks the model" do
      call = refund_call
      chat = paused(call)
      Chat.find(chat.id).decline(call.id, *note)

      record = Chat.find(chat.id)
      expect(record).not_to be_waiting
      expect(record.pending_questions).to be_empty
      expect(resumed(record).content).to eq('Done')

      expect(result_of(call)).to eq(result)
      expect(requests.size).to eq(1)
    end
  end

  it "refuses a declined call once the agent's tools leave it out, and asks the model" do
    call = refund_call
    chat = paused(call, chat: refunds_agent.create!(model: model_for(:openai)), tools: [])
    refunds_agent.find(chat.id).decline(call.id, 'The order shipped already')

    resumed(plain_agent.find(chat.id))

    expect(result_of(call)).to eq('{"error":"The order shipped already"}')
    expect(requests.size).to eq(1)
  end

  it 'refuses a call declined before 2.2 once its tool is gone' do
    call = refund_call
    chat = paused(call)
    RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: call.id).update_all(approval: 'denied', mcp_result: nil)

    resumed(Chat.find(chat.id))

    expect(result_of(call)).to eq('{"error":"The user denied the issue_refund tool call."}')
    expect(requests.size).to eq(1)
  end

  it 'refuses a declined call of an MCP server that is gone' do
    files = files_class.new
    call = RubyLLM::ToolCall.new(id: 'call_add', name: 'add', arguments: { 'a' => 2, 'b' => 3 })
    chat = paused(call, tools: [], mcp: files)
    files.close
    Chat.find(chat.id).decline(call.id, 'Not now')

    closed_port = TCPServer.new('127.0.0.1', 0).then { |server| server.addr[1].tap { server.close } }
    WebMock.disable!
    resumed(Chat.find(chat.id).with_mcp(RubyLLM.mcp(url: "http://127.0.0.1:#{closed_port}/mcp", name: 'files')))

    expect(result_of(call)).to eq('{"error":"Not now"}')
    expect(requests.size).to eq(1)
  ensure
    WebMock.enable!
    RubyLLM::MCP::Outages.clear
  end

  it 'sends the refusal of a declined remote call once its provider tool is gone' do
    raw = { 'type' => 'mcp_approval_request', 'id' => 'approval_1', 'name' => 'search',
            'arguments' => '{"query":"Ruby"}', 'server_label' => 'docs' }
    agent = Class.new(RubyLLM::Agent) do
      chat_class Chat
      provider_tools mcp: { name: 'docs', url: 'https://example.test/mcp', require_approval: 'always' }
    end
    agent.model model_for(:openai), provider: :openai, protocol: :responses
    chat = agent.create!
    protocol = RubyLLM::Protocols::Responses.allocate
    body = { 'status' => 'completed', 'output' => [raw] }
    chat.add_message(protocol.send(:parse_completion_body, body, raw: instance_double(Faraday::Response, body:)))
    agent.find(chat.id).decline(chat.pending_questions.sole, 'Not on this account')

    record = Chat.find(chat.id).with_model(model_for(:openai), provider: :openai, protocol: :responses)
    resumed(record)

    result = record.messages_association.find_by!(role: 'tool').to_llm
    expect(result.raw_content.sole).to include('approve' => false, 'reason' => 'Not on this account')
    expect(requests.size).to eq(1)
  end

  it 'stops a resume that makes no progress instead of spinning' do
    call = refund_call
    chat = paused(call)
    Chat.find(chat.id).decline(call.id)
    record = Chat.find(chat.id).with_tools(refund)
    allow(record).to receive(:claim_persisted_tool_calls).and_return([])

    expect { resumed(record) }.to raise_error(/no progress on tool calls #{call.id}/)
    expect(requests).to be_empty
    expect(result_of(call)).to be_nil
    expect(Chat.find(chat.id).reply_error).to be_present if Chat.column_names.include?('reply_error')
  end
end
