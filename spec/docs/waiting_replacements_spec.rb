# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Replacements for the waiting methods in the upgrade guide', type: :task do
  include_context 'with configured RubyLLM'

  let(:replacements) do
    File.read(File.expand_path('../../docs/_reference/upgrading.md', __dir__))
        .scan(/^\| `chat\.(\w+\??)` \| `(.+)` \|$/).to_h
  end

  let(:tools) do
    {
      refund: ['Refunds an order', -> { 'Refunded' }, true],
      lookup: ['Looks up an order', -> { ask('Which order?') }, false],
      render: ['Renders a report', -> { RubyLLM::Task.new(status: :working) }, false],
      sign: ['Sends a contract for signature', -> { RubyLLM::Task.new(status: :input_required) }, false]
    }.map do |name, (text, execute, approval)|
      Class.new(RubyLLM::Tool) do
        description text
        requires_approval if approval
        define_method(:name) { name.to_s }
        define_method(:execute, &execute)
      end
    end
  end

  let(:removed) do
    {
      approval: [true, ['refund'], false, [], false, true],
      question: [false, [], true, ['Which order?'], false, true],
      working_task: [false, [], false, [], true, false],
      task_for_a_person: [false, [], false, [], true, true],
      approval_beside_a_call_that_can_run: [false, ['refund'], false, [], false, false],
      answer: [false, [], false, [], false, false]
    }.transform_values do |values|
      %w[awaiting_approval? pending_approvals awaiting_input? pending_inputs awaiting_tasks? awaiting_person?]
        .zip(values).to_h
    end
  end

  def calling(*names)
    tool_calls = names.to_h { |name| ["call_#{name}", RubyLLM::ToolCall.new(id: "call_#{name}", name:, arguments: {})] }
    RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1, tool_calls:)
  end

  def answer = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)

  def waiting_chat(state, chat)
    reply = { approval: calling('refund'), question: calling('lookup'), working_task: calling('render'),
              task_for_a_person: calling('sign'), approval_beside_a_call_that_can_run: calling('refund', 'render'),
              answer: answer }.fetch(state)
    chat.with_tools(*tools)
    allow((chat.respond_to?(:to_llm) ? chat.to_llm : chat).provider).to receive(:complete).and_return(reply)
    if state == :approval_beside_a_call_that_can_run
      chat.add_message(role: :user, content: 'Refund and render')
      chat.generate
    else
      chat.ask('Help')
    end
    chat
  end

  def replaced(code, chat)
    scope = TOPLEVEL_BINDING.dup
    scope.local_variable_set(:chat, chat)
    value = scope.eval(code)
    return value unless value.is_a?(Array)

    value.map { |item| item.is_a?(RubyLLM::Question) ? item.message : item.name }
  end

  it 'lists every waiting method 2.2 removes, and they are gone from chats, records, and agents' do
    expect(replacements.keys).to match_array(removed.fetch(:answer).keys)
    gone = [RubyLLM::Chat, Chat, RubyLLM::Agent].flat_map do |owner|
      replacements.keys.select { |name| owner.method_defined?(name) }
    end
    expect(gone).to be_empty
  end

  %i[approval question working_task task_for_a_person approval_beside_a_call_that_can_run answer].each do |state|
    it "gives what the removed methods gave for a chat, and its agent, with #{state.to_s.tr('_', ' ')}" do
      chat = waiting_chat(state, RubyLLM.chat(model: model_for(:openai)))
      agent = Class.new(RubyLLM::Agent).new(chat:)

      expect(replacements.transform_values { |code| replaced(code, chat) }).to eq(removed.fetch(state))
      expect(replacements.transform_values { |code| replaced(code, agent) }).to eq(removed.fetch(state))
    end

    it "gives what the removed methods gave for a chat record with #{state.to_s.tr('_', ' ')}" do
      chat = waiting_chat(state, Chat.create!(model: model_for(:openai)))

      expect(replacements.transform_values { |code| replaced(code, chat) }).to eq(removed.fetch(state))
    end
  end
end
