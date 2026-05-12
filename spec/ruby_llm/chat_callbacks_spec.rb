# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class CallbackProbeTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Returns a callback probe result'

    def execute
      'tool result'
    end
  end

  def stub_completion(chat, *messages)
    provider = chat.instance_variable_get(:@provider)
    allow(provider).to receive(:complete).and_return(*messages)
  end

  it 'keeps on_new_message as an overriding callback' do
    calls = []
    chat = described_class.new(model: 'gpt-4.1-nano')
    allow(RubyLLM.logger).to receive(:warn)

    chat.on_new_message { calls << :first }
    chat.on_new_message { calls << :second }

    chat.instance_variable_get(:@on)[:new_message].call

    expect(calls).to eq([:second])
    expect(RubyLLM.logger).to have_received(:warn).with(
      '`on_new_message` is deprecated and will be removed in RubyLLM 2.0. ' \
      'Use `before_message` instead.'
    ).twice
  end

  it 'runs additive message callbacks before the overriding callbacks' do
    calls = []
    chat = described_class.new(model: 'gpt-4.1-nano')
    stub_completion(chat, RubyLLM::Message.new(role: :assistant, content: 'done'))
    allow(RubyLLM.logger).to receive(:warn)

    chat.before_message { calls << :before_one }
        .before_message { calls << :before_two }
        .on_new_message { calls << :on_new_message }
        .after_message { |message| calls << [:after_one, message.content] }
        .after_message { |message| calls << [:after_two, message.content] }
        .on_end_message { |message| calls << [:on_end_message, message.content] }

    chat.ask('Hello')

    expect(calls).to eq([
                          :before_one,
                          :before_two,
                          :on_new_message,
                          [:after_one, 'done'],
                          [:after_two, 'done'],
                          [:on_end_message, 'done']
                        ])
  end

  it 'runs additive tool callbacks before the overriding callbacks' do
    calls = []
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'callback_probe', arguments: {})
    tool_message = RubyLLM::Message.new(
      role: :assistant,
      content: nil,
      tool_calls: { 'call_1' => tool_call }
    )
    final_message = RubyLLM::Message.new(role: :assistant, content: 'complete')
    chat = described_class.new(model: 'gpt-4.1-nano').with_tool(CallbackProbeTool)
    stub_completion(chat, tool_message, final_message)
    allow(RubyLLM.logger).to receive(:warn)

    chat.before_tool_call { |call| calls << [:before_tool_call, call.name] }
        .on_tool_call { |call| calls << [:on_tool_call, call.name] }
        .after_tool_result { |result| calls << [:after_tool_result, result] }
        .on_tool_result { |result| calls << [:on_tool_result, result] }

    chat.ask('Use the tool')

    expect(calls).to eq([
                          [:before_tool_call, 'callback_probe'],
                          [:on_tool_call, 'callback_probe'],
                          [:after_tool_result, 'tool result'],
                          [:on_tool_result, 'tool result']
                        ])
  end
end
