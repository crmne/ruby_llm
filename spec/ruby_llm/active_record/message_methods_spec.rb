# frozen_string_literal: true

require 'rails_helper'
require 'ruby_llm/active_record/message_methods'

RSpec.describe RubyLLM::ActiveRecord::MessageMethods do
  subject(:message_instance) { message_class.new }

  let(:message_class) do
    Class.new do
      include RubyLLM::ActiveRecord::MessageMethods

      attr_accessor :content
    end
  end

  it 'extracts error from hash content' do
    message_instance.content = { error: 'tool failed' }
    expect(message_instance.tool_error_message).to eq('tool failed')
  end

  it 'extracts error from JSON string content' do
    message_instance.content = '{"error":"tool failed"}'
    expect(message_instance.tool_error_message).to eq('tool failed')
  end

  it 'parses structured output content' do
    message_instance.content = '{"name":"Alice","age":30}'
    expect(message_instance.parsed).to eq({ 'name' => 'Alice', 'age' => 30 })
  end

  it 'returns nil from parsed when there is no content' do
    message_instance.content = nil
    expect(message_instance.parsed).to be_nil
  end

  it 'returns nil for invalid content' do
    message_instance.content = 'not-json'
    expect(message_instance.tool_error_message).to be_nil
  end

  describe 'Rails-backed message records' do
    let(:chat) { Chat.create!(model: 'gpt-4.1-nano') }

    def tool_call
      RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'lookup', arguments: {})
    end

    it 'names the partial by role' do
      expect(chat.add_message(role: :user, content: 'hi').to_partial_path).to eq('messages/user')
      expect(chat.add_message(role: :tool, content: 'result').to_partial_path).to eq('messages/tool')
      expect(Message.new(role: '').to_partial_path).to eq('messages/assistant')
    end

    it 'names the tool-call partial for a message that calls tools' do
      call = tool_call
      record = chat.add_message(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
      )

      expect(record.to_partial_path).to eq('messages/tool_calls')
      expect(record).to be_tool_call
      expect(record).not_to be_tool_result
    end

    it 'exposes the tool call a result belongs to' do
      call = tool_call
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
      result = chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: call.id))

      expect(result).to be_tool_result
      expect(result.parent_tool_call.id).to eq(call.id)
      expect(result.to_llm.tool_call_id).to eq(call.id)
    end

    it 'collects the results of the tool calls it made' do
      call = tool_call
      caller_record = chat.add_message(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
      )
      result = chat.add_message(RubyLLM::Message.new(role: :tool, content: 'done', tool_call_id: call.id))

      expect(caller_record.tool_results).to eq([result])
    end

    it 'reaches its chat through the declared association' do
      record = chat.add_message(role: :user, content: 'hi')

      expect(record.chat_association).to eq(chat)
    end
  end
end
