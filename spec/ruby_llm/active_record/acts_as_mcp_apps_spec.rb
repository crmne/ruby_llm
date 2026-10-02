# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }
  let(:weather) do
    command = [RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)]
    Class.new(RubyLLM::MCP) do
      command(*command)
      extension :apps
    end.new
  end

  after { weather.close }

  def answered_chat(tool_name, arguments)
    chat = Chat.create!(model: 'gpt-4.1-nano').with_mcp(weather)
    chat.add_message(
      RubyLLM::Message.new(role: :assistant, content: '',
                           tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: tool_name, arguments:) })
    )
    allow(chat.to_llm.provider).to receive(:complete).and_return(
      RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    )
    chat.complete
    chat
  end

  it 'keeps the result of a tool with a UI on its tool call to render it again after a reload' do
    chat = answered_chat('forecast', { 'city' => 'Rome' })

    tool_message = Chat.find(chat.id).messages_association.find_by(role: 'tool')
    expect(tool_message.parent_tool_call.arguments).to eq('city' => 'Rome')
    expect(tool_message.mcp_result).to have_attributes(
      ui_uri: 'ui://spec/forecast', text: 'Sunny in Rome',
      structured: { 'city' => 'Rome', 'temperature' => 24 }, meta: { 'com.example/station' => 'spec' }
    )
    expect(Chat.find(chat.id).to_llm.messages.find(&:tool_result?).mcp_result.ui_uri).to eq('ui://spec/forecast')
  end

  it 'stores a failed call as 2.0 did' do
    chat = answered_chat('fail', {})

    tool_message = Chat.find(chat.id).messages_association.find_by(role: 'tool')
    expect(tool_message.content).to eq('{"error":"Something broke"}')
    expect(tool_message.tool_error_message).to eq('Something broke')
    expect(tool_message.mcp_result).to be_nil
  end

  it 'keeps nothing for tools without a UI' do
    chat = answered_chat('add', { 'a' => 2, 'b' => 3 })

    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).mcp_result).to be_nil
    expect(Chat.find(chat.id).messages_association.find_by(role: 'tool').mcp_result).to be_nil
  end
end
