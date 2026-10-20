# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  include_context 'with configured RubyLLM'

  let(:ask_handler) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'AskHandler'

      description 'Ask the team'
      parameters do
        string :question, description: 'What to ask'
      end

      def execute(question:)
        answer = ask(question, answer: { type: 'string', title: 'Answer', required: true })
        answer.accepted? ? "Team says: #{answer[:answer]}" : 'Nobody answered'
      end
    end
  end

  let(:two_questions) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'Survey'

      description 'Ask twice'

      def execute
        first = ask('Name?', name: { type: 'string' })
        second = ask('Color?', color: { type: 'string', enum: %w[red blue] })
        "#{first[:name]} likes #{second[:color]}"
      end
    end
  end

  let(:chat) { RubyLLM::Chat.new(model: model_for(:anthropic)) }

  def tool_call(name, arguments)
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name:, arguments:) })
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'Done', model: model_for(:anthropic), input_tokens: 1,
                         output_tokens: 1)
  end

  def result
    chat.messages.find { |message| message.role == :tool }&.content
  end

  it 'pauses the call on its question, and runs it again with the answer' do
    allow(chat.provider).to receive(:complete)
      .and_return(tool_call('ask_handler', { 'question' => 'Engine DJ?' }), answer)

    chat.with_tools(ask_handler).ask('Will you support Engine DJ?')

    expect(chat).to be_awaiting_input
    request = chat.pending_inputs.first
    expect(request).to have_attributes(message: 'Engine DJ?', url: nil, tool_call: have_attributes(name: 'ask_handler'))
    expect(request.fields.map(&:name)).to eq([:answer])
    expect(request.fields.first).to be_required

    chat.answer(request, answer: 'Planned, no date').complete

    expect(result).to eq('Team says: Planned, no date')
    expect(chat).not_to be_awaiting_input
  end

  it 'resumes a declined question' do
    allow(chat.provider).to receive(:complete).and_return(tool_call('ask_handler', { 'question' => 'Refund?' }), answer)

    chat.with_tools(ask_handler).ask('Refund me')
    chat.decline(chat.pending_inputs.first).complete

    expect(result).to eq('Nobody answered')
  end

  it 'asks several questions one after another' do
    allow(chat.provider).to receive(:complete).and_return(tool_call('survey', {}), answer)

    chat.with_tools(two_questions).ask('Survey me')
    chat.answer(chat.pending_inputs.first, name: 'Ada')
    chat.complete

    expect(chat.pending_inputs.map(&:message)).to eq(['Color?'])
    expect(chat.pending_inputs.first.fields.first.choices).to eq(%w[red blue])

    chat.answer(chat.pending_inputs.first, color: 'blue').complete

    expect(result).to eq('Ada likes blue')
  end

  it 'pauses on a task after its question, and resumes the task' do
    tool = Class.new(RubyLLM::Tool) do
      def self.name = 'Deploy'

      description 'Deploy after asking'

      def execute
        target = ask('Where?', target: { type: 'string' })[:target]
        RubyLLM::Task.new(status: :input_required, data: { 'target' => target })
      end

      def resume(task, **) = "Deployed to #{task.data['target']}"
    end
    allow(chat.provider).to receive(:complete).and_return(tool_call('deploy', {}), answer)

    chat.with_tools(tool).ask('Deploy it')
    chat.answer(chat.pending_inputs.first, target: 'staging').complete

    expect(chat).to be_awaiting_tasks
    expect(chat.pending_tasks.first.data).to eq('target' => 'staging')

    chat.complete

    expect(result).to eq('Deployed to staging')
  end

  it 'raises outside a chat' do
    expect { ask_handler.new.call(question: 'Anyone?') }
      .to raise_error(RubyLLM::InputRequiredError, /AskHandler|ask_handler/)
  end

  it 'keeps MCP input errors catchable as the general one' do
    expect(RubyLLM::MCP::InputRequiredError.ancestors).to include(RubyLLM::InputRequiredError)
    expect(RubyLLM::MCP::InputRequest).to be(RubyLLM::InputRequest)
  end
end
