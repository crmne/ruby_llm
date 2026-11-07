# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/open_telemetry'

RSpec.describe RubyLLM::OpenTelemetry do
  include_context 'with configured RubyLLM'
  include_context 'with OpenTelemetry tracing'

  %i[thread fiber].each do |isolation|
    it "traces persisted chats and fiber tools under #{isolation} execution isolation" do
      previous = ActiveSupport::IsolatedExecutionState.isolation_level
      ActiveSupport::IsolatedExecutionState.isolation_level = isolation
      stub_const('TelemetryCountChats', Class.new(RubyLLM::Tool) do
        def execute
          sleep 0.01
          Chat.count
        end
      end)
      model = model_for(:openai, :temperature)
      calls = Array.new(2) { SecureRandom.hex(8) }.to_h do |id|
        [id, RubyLLM::ToolCall.new(id:, name: 'telemetry_count_chats', arguments: {})]
      end
      in_reactor do
        Rails.application.executor.wrap do
          RubyLLM.workflow('persisted chat') do
            chat = Chat.create!(model:).with_tools(TelemetryCountChats).with_tool_options(concurrency: :fibers)
            allow(chat.to_llm.provider).to receive(:complete).and_return(
              RubyLLM::Message.new(role: :assistant, model:, content: nil, tool_calls: calls),
              RubyLLM::Message.new(role: :assistant, model:, content: 'done', input_tokens: 5, output_tokens: 1)
            )

            expect(chat.ask('Count chats twice').content).to eq('done')
            expect(chat.messages.where(role: 'tool').count).to eq(2)
          end
        end
      end

      workflow = spans.find { |span| span.name == 'invoke_workflow persisted chat' }
      children = spans.reject { |span| span == workflow }
      expect(children.size).to eq(4)
      expect(children.map(&:parent_span_id).uniq).to eq([workflow.span_id])
      expect(children.map { |span| span.attributes['gen_ai.operation.name'] })
        .to contain_exactly('chat', 'execute_tool', 'execute_tool', 'chat')
      expect(OpenTelemetry::Trace.current_span.context).not_to be_valid
    ensure
      ActiveSupport::IsolatedExecutionState.isolation_level = previous
    end
  end

  it 'records the conversation id of a persisted agent chat on its agent span' do
    stub_const('TelemetryPersistedAgent', Class.new(RubyLLM::Agent) do
      chat_class Chat
      model model_for(:openai, :temperature)
    end)
    model = model_for(:openai, :temperature)
    chat = TelemetryPersistedAgent.create!
    allow(chat.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, model:, content: 'done', input_tokens: 5, output_tokens: 1))

    chat.ask('Hello')

    run = spans.find { |span| span.name == 'invoke_agent TelemetryPersistedAgent' }
    expect(run.attributes).to include('gen_ai.agent.name' => 'TelemetryPersistedAgent',
                                      'gen_ai.conversation.id' => chat.id.to_s)
    expect(spans.find { |span| span.name == "chat #{model}" }.parent_span_id).to eq(run.span_id)
  end
end
