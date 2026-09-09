# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:call_id) { "approval_#{SecureRandom.hex(6)}" }
  let(:raw_approval) do
    { 'type' => 'mcp_approval_request', 'id' => call_id, 'name' => 'search',
      'arguments' => '{"query":"Ruby"}', 'server_label' => 'docs' }
  end
  let(:agent) do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      server_tools mcp: { name: 'docs', url: 'https://example.test/mcp', require_approval: 'always' }
    end
    agent_class.model model_for(:openai), provider: :openai, protocol: :responses
    agent_class
  end

  def parked_chat
    chat = agent.create!
    protocol = RubyLLM::Protocols::Responses.allocate
    body = { 'status' => 'completed', 'output' => [raw_approval] }
    message = protocol.send(:parse_completion_body, body, raw: instance_double(Faraday::Response, body:))
    chat.add_message(message)
    chat
  end

  [true, false].each do |approved|
    it "preserves a remote #{approved ? 'approval' : 'denial'} through Agent.find and Rails result serialization" do
      chat = parked_chat
      restored = agent.find(chat.id)
      call = restored.pending_approvals.first
      expect(call.to_llm).to have_attributes(remote?: true, arguments: { 'query' => 'Ruby' })
      expect(restored).to be_awaiting_approval
      approved ? restored.approve(call) : restored.deny(call)

      resumed = agent.find(chat.id)
      resumed.run_tools.run_tools
      result = resumed.messages_association.find_by!(role: 'tool')
      expect(result.to_llm.raw_content).to eq([
                                                { 'type' => 'mcp_approval_response', 'approval_request_id' => call_id,
                                                  'approve' => approved }
                                              ])
      expect(result.to_llm.tool_call_id).to eq(call_id)
      expect(resumed.messages_association.where(role: 'tool').count).to eq(1)
      expect(agent.find(chat.id).render[:input]).to include(raw_approval, *result.to_llm.raw_content)
    end
  end

  it 'reads a decision written by another worker while the query cache is enabled' do
    chat = parked_chat
    pending = chat.pending_approvals.first
    RubyLLM::ActiveRecord::ToolCall.cache do
      expect(chat).to be_awaiting_approval
      path = File.expand_path(RubyLLM::ActiveRecord::ToolCall.connection_db_config.database, Rails.root)
      database = SQLite3::Database.new(path)
      database.execute('UPDATE ruby_llm_tool_calls SET approval = ? WHERE id = ?', ['approved', pending.id])
      database.close

      expect(chat).not_to be_awaiting_approval
      expect(chat.pending_approvals).to be_empty
    end
  end
end
