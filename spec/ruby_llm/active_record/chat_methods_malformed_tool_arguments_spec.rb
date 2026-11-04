# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:call_id) { "call_#{SecureRandom.hex(4)}" }
  let(:malformed) { '{"path":"/tmp' }
  let(:lookup_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do |**arguments|
        runs << arguments
        'found'
      end
    end
  end

  # What a worker leaves when it dies after saving the response and before
  # answering its malformed call.
  def unanswered_chat
    chat = Chat.create!(model: model_for(:openai))
    chat.add_message(role: :user, content: 'Look it up')
    call = RubyLLM::ToolCall.new(id: call_id, name: 'lookup', malformed_arguments: malformed)
    chat.add_message(role: :assistant, content: '', tool_calls: { call_id => call })
    chat
  end

  it 'stores the text of malformed arguments in the arguments column' do
    unanswered_chat

    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).arguments).to eq(malformed)
  end

  it 'stores a NUL in malformed arguments as its escape, which jsonb accepts' do
    chat = Chat.create!(model: model_for(:openai))
    call = RubyLLM::ToolCall.new(id: call_id, name: 'lookup', malformed_arguments: "{\"q\":\"a\u0000")
    chat.add_message(role: :assistant, content: '', tool_calls: { call_id => call })

    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).arguments).to eq('{"q":"a\u0000')
  end

  it 'keeps an unanswered malformed call malformed after a reload, and answers it without running the tool' do
    chat = Chat.find(unanswered_chat.id).with_tools(lookup_tool)
    allow(chat.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Answered', input_tokens: 1, output_tokens: 1))

    call = chat.to_llm.messages.last.tool_calls[call_id]
    expect([call.arguments, call.malformed_arguments]).to eq([{}, malformed])

    chat.complete

    expect(executions).to be_empty
    result = RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).result
    expect(result.content).to include('The arguments for lookup were not valid JSON')
    expect(chat.messages.last.content).to eq('Answered')
  end
end
