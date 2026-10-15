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
    include_context 'with configured RubyLLM'

    let(:chat) { Chat.create!(model: model_for(:openai, :temperature)) }

    def tool_call
      RubyLLM::ToolCall.new(id: "call_#{SecureRandom.hex(4)}", name: 'lookup', arguments: {})
    end

    it 'reads the model of the successful attempt after reloading the message' do
      record = chat.add_message(role: :assistant, content: 'Answer')
      chat.ruby_llm_usages.create!(
        message: record, operation: 'chat', provider: 'openai', model: 'gpt-4.1', status: 'succeeded'
      )
      chat.ruby_llm_usages.create!(
        message: record, operation: 'chat', provider: 'openai', model: model_for(:openai,
                                                                                 :temperature), status: 'failed'
      )

      expect(record.reload.model).to eq('gpt-4.1')
      expect(record.model_info.id).to eq('gpt-4.1')
      expect(chat.add_message(role: :user, content: 'Continue').model).to be_nil
    end

    it 'exposes the plain message finish predicates after reloading' do
      { stop: :stopped?, max_tokens: :max_tokens?, tool_calls: :tool_call_stop?,
        content_filter: :content_filtered? }.each do |reason, predicate|
        record = chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', finish_reason: reason))

        expect(record.reload.public_send(predicate)).to be(true)
        expect(record.stopped?).to eq(reason == :stop)
      end
    end

    it 'uses the successful attempt provider when reloading an overlapping model id' do
      original = RubyLLM.models.find(model_for(:openai, :temperature), provider: :openai)
      custom = RubyLLM::Model.new(original.to_h.merge(provider: 'custom'))
      registry = RubyLLM::Models.new([original, custom])
      record = chat.add_message(role: :assistant, content: 'Answer')
      chat.ruby_llm_usages.create!(
        message: record, operation: 'chat', provider: 'custom', model: custom.id, status: 'succeeded'
      )
      chat.ruby_llm_usages.create!(
        message: record, operation: 'chat', provider: 'openai', model: original.id, status: 'failed'
      )
      allow(RubyLLM).to receive(:models).and_return(registry)

      expect(record.reload.model_info).to eq(custom)
      expect(record.to_llm.model_info).to eq(custom)
    end

    it 'recognizes tool calls when the provider reports a normal stop' do
      call = tool_call
      record = chat.add_message(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }, finish_reason: :stop)
      )

      expect(record.reload).to be_tool_call_stop
      expect(record).not_to be_stopped
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

    describe 'exporting the recorded cost' do
      let(:model) { model_for(:openrouter) }
      let(:chat) { Chat.create!(model: model, provider: :openrouter) }

      def reply(usage)
        body = { model: model, usage: usage,
                 choices: [{ message: { role: 'assistant', content: 'Answer' }, finish_reason: 'stop' }] }
        stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return_json(body: body)
        chat.ask('Hello')
        chat.messages.where(role: 'assistant').last
      end

      def restore(record)
        RubyLLM::Message.new(JSON.parse(JSON.generate(record.to_llm.to_h)).transform_keys(&:to_sym))
      end

      it 'keeps the cost the provider reported through a JSON round trip' do
        record = reply(prompt_tokens: 1000, completion_tokens: 2000, cost: 0.123)

        expect(restore(record).cost.total).to eq(0.123)
        expect(restore(record).cost.input).to eq(record.cost.input)
        expect(RubyLLM::Message.new(record.to_llm.to_h).cost.total).to eq(0.123)
      end

      it 'keeps the total unknown when an attempt has no recorded cost' do
        record = reply(prompt_tokens: 1000, completion_tokens: 2000, cost: 0.123)
        chat.ruby_llm_usages.create!(message: record, operation: 'chat', provider: 'openrouter', model: model,
                                     status: 'failed')

        expect(restore(record).cost.total).to be_nil
        expect(restore(record).cost.output).to eq(record.cost.output)
      end

      it 'adds no cost to a message without recorded usage' do
        record = chat.add_message(role: :user, content: 'Hello')

        expect(record.to_llm.to_h).not_to have_key(:cost)
      end
    end
  end
end
