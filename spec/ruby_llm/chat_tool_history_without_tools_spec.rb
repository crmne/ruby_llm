# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  include_context 'with configured RubyLLM'

  # Converse refuses toolUse and toolResult blocks without a toolConfig, so a
  # request that declares no tools, like a summary of a chat that called
  # them, sends its tool rounds as text.
  it 'answers on Bedrock Converse over a history of tool calls without declaring tools' do
    chat = RubyLLM.chat(model: model_for(:bedrock), provider: :bedrock)
    call = RubyLLM::ToolCall.new(id: 'tooluse_weather_1', name: 'weather', arguments: { 'city' => 'Berlin' })
    chat.add_message(role: :user, content: "What's the weather in Berlin?")
    chat.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
    chat.add_message(role: :tool, content: '15°C and sunny', tool_call_id: call.id)

    response = chat.ask('In one sentence, what did the weather tool report?')

    expect(chat.tools).to be_empty
    expect(response.content).to include('15')
  end
end
