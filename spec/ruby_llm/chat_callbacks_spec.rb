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

  class ProgressProbeTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Reports progress while it works'

    def execute(label:)
      progress "Starting #{label}"
      sleep 0.01
      progress "Finishing #{label}", value: 2, total: 2
      "#{label} done"
    end
  end

  def stub_completion(chat, *messages)
    provider = chat.instance_variable_get(:@provider)
    allow(provider).to receive(:complete).and_return(*messages)
  end

  it 'runs additive message callbacks in order' do
    calls = []
    chat = described_class.new(model: model_for(:openai, :temperature))
    stub_completion(chat, RubyLLM::Message.new(role: :assistant, content: 'done'))

    chat.before_message { calls << :before_one }
        .before_message { calls << :before_two }
        .after_message { |message| calls << [:after_one, message.content] }
        .after_message { |message| calls << [:after_two, message.content] }

    chat.ask('Hello')

    expect(calls).to eq([
                          :before_one,
                          :before_two,
                          [:after_one, 'done'],
                          [:after_two, 'done']
                        ])
  end

  it 'runs additive tool callbacks in order' do
    calls = []
    tool_call = RubyLLM::ToolCall.new(id: 'call_1', name: 'callback_probe', arguments: {})
    tool_message = RubyLLM::Message.new(
      role: :assistant,
      content: nil,
      tool_calls: { 'call_1' => tool_call }
    )
    final_message = RubyLLM::Message.new(role: :assistant, content: 'complete')
    chat = described_class.new(model: model_for(:openai, :temperature)).with_tools(CallbackProbeTool)
    stub_completion(chat, tool_message, final_message)

    chat.before_tool_call { |call| calls << [:before_tool_call, call.name] }
        .after_tool_result { |result| calls << [:after_tool_result, result] }

    chat.ask('Use the tool')

    expect(calls).to eq([
                          [:before_tool_call, 'callback_probe'],
                          [:after_tool_result, 'tool result']
                        ])
  end

  describe 'tool progress' do
    def progress_calls(*labels)
      tool_calls = labels.to_h do |label|
        id = "call_#{label}"
        [id, RubyLLM::ToolCall.new(id:, name: 'progress_probe', arguments: { 'label' => label })]
      end
      RubyLLM::Message.new(role: :assistant, content: nil, tool_calls:)
    end

    let(:chat) { described_class.new(model: model_for(:openai, :temperature)).with_tools(ProgressProbeTool) }

    it 'passes each report to after_tool_progress with its tool call, before the result' do
      calls = []
      stub_completion(chat, progress_calls('a'), RubyLLM::Message.new(role: :assistant, content: 'complete'))

      chat.after_tool_progress { |call, progress| calls << [call.id, progress.message, progress.fraction] }
          .after_tool_result { |result| calls << [:result, result] }
      chat.ask('Use the tool')

      expect(calls).to eq([['call_a', 'Starting a', nil], ['call_a', 'Finishing a', 1.0], [:result, 'a done']])
    end

    %i[threads fibers].each do |mode|
      it "keeps progress with its own tool call when tools run with #{mode}" do
        calls = Queue.new
        chat.with_tool_options(concurrency: mode)
        stub_completion(chat, progress_calls('a', 'b'), RubyLLM::Message.new(role: :assistant, content: 'complete'))

        chat.after_tool_progress { |call, progress| calls << [call.id, progress.message] }
        chat.ask('Use the tools')

        reports = Array.new(calls.size) { calls.pop }.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
        expect(reports).to eq('call_a' => ['Starting a', 'Finishing a'], 'call_b' => ['Starting b', 'Finishing b'])
      end
    end

    it 'passes reports from threads the tool starts', skip: (RUBY_VERSION >= '3.2' ? false : 'needs fiber storage') do
      stub_const('FanOutTool', Class.new(RubyLLM::Tool) do
        def execute
          Thread.new { progress 'Reading in the background' }.join
          'done'
        end
      end)
      calls = []
      stub_completion(chat.with_tools(FanOutTool),
                      RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: {
                                             'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'fan_out')
                                           }),
                      RubyLLM::Message.new(role: :assistant, content: 'complete'))

      chat.after_tool_progress { |call, progress| calls << [call.id, progress.message] }
      chat.ask('Use the tool')

      expect(calls).to eq([['call_1', 'Reading in the background']])
    end

    it 'runs tools that report progress without a callback' do
      stub_completion(chat, progress_calls('a'), RubyLLM::Message.new(role: :assistant, content: 'complete'))

      chat.ask('Use the tool')

      expect(chat.messages.find(&:tool_result?).content).to eq('a done')
    end
  end
end
