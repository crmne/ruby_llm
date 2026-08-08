# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class EchoTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Echoes the given text'
    parameter :text, description: 'Text to echo'

    def execute(text:)
      text
    end
  end

  let(:chat) { described_class.new(model: 'claude-haiku-4-5').with_tools(EchoTool) }
  let(:answer_message) do
    RubyLLM::Message.new(
      role: :assistant, content: 'hello', model: 'claude-haiku-4-5', input_tokens: 1, output_tokens: 1
    )
  end

  def tool_call_message(name: 'echo')
    RubyLLM::Message.new(
      role: :assistant,
      content: '',
      tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: name, arguments: { 'text' => 'hello' }) }
    )
  end

  def multi_tool_call_message
    RubyLLM::Message.new(
      role: :assistant,
      content: '',
      tool_calls: {
        'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'echo', arguments: { 'text' => 'first' }),
        'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'echo', arguments: { 'text' => 'second' })
      }
    )
  end

  def tool_result_message(tool_call_id, content)
    RubyLLM::Message.new(role: :tool, content: content, tool_call_id: tool_call_id)
  end

  describe '#ask_later' do
    it 'stages the question without asking the model' do
      allow(chat.provider).to receive(:complete)

      chat.ask_later('Echo "hello" back to me.')

      expect(chat.provider).not_to have_received(:complete)
      expect(chat).not_to be_complete
      expect(chat.messages.last.role).to eq(:user)
    end
  end

  describe '#complete?' do
    it 'walks the agentic-loop state machine' do
      expect(chat).to be_complete # nothing staged yet

      chat.ask_later('Echo "hello" back to me.')
      expect(chat).not_to be_complete # model owes a response

      chat.add_message tool_call_message
      expect(chat).not_to be_complete # tools owe results

      chat.run_tools
      expect(chat).not_to be_complete # model owes a response again

      chat.add_completion answer_message
      expect(chat).to be_complete # answered, no tools
    end

    it 'is not complete while a tool round is partially answered' do
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')

      expect(chat).not_to be_complete
    end

    it 'is complete on a chat with only instructions' do
      expect(chat.with_instructions('Be terse.')).to be_complete
    end

    it 'ignores trailing instructions when deciding whether the model owes a response' do
      chat.ask_later('Echo "hello" back to me.')
      chat.with_instructions('Be terse.')

      expect(chat).not_to be_complete
    end
  end

  describe '#cancel!' do
    it 'marks the chat for one-shot cancellation' do
      expect(chat.cancel!).to be(chat)
      expect(chat).to be_cancelled
    end

    it 'raises before the next model request and clears the cancellation flag' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo "hello" back to me.')
      chat.cancel!

      expect { chat.step }.to raise_error(RubyLLM::CancelledError, 'Chat generation cancelled')
      expect(chat).not_to be_cancelled
      expect(chat.provider).not_to have_received(:complete)
    end

    it 'raises while streaming when the block cancels the chat' do
      allow(chat.provider).to receive(:complete) do |_messages, **_kwargs, &block|
        block.call(RubyLLM::Chunk.new(role: :assistant, content: 'one'))
        block.call(RubyLLM::Chunk.new(role: :assistant, content: 'two'))
        answer_message
      end

      chat.ask_later('Count slowly.')
      chunks = []

      expect do
        chat.complete do |chunk|
          chunks << chunk.content
          chat.cancel!
        end
      end.to raise_error(RubyLLM::CancelledError, 'Chat generation cancelled')

      expect(chunks).to eq(['one'])
      expect(chat).not_to be_cancelled
      expect(chat.messages.map(&:role)).to eq([:user])
    end

    it 'raises before appending a non-streaming response when cancelled during the request' do
      allow(chat.provider).to receive(:complete) do |_messages, **|
        chat.cancel!
        answer_message
      end

      chat.ask_later('Echo "hello" back to me.')

      expect { chat.generate }.to raise_error(RubyLLM::CancelledError, 'Chat generation cancelled')
      expect(chat).not_to be_cancelled
      expect(chat.messages.map(&:role)).to eq([:user])
      expect(chat.cost.total).to be_positive
    end

    it 'raises before executing pending tool calls' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo "hello" back to me.')
      chat.add_message tool_call_message
      chat.cancel!

      expect { chat.run_tools }.to raise_error(RubyLLM::CancelledError, 'Chat generation cancelled')
      expect(chat.messages.last).to be_tool_call
    end
  end

  describe '#generate' do
    it 'calls the model once and appends the response' do
      allow(chat.provider).to receive(:complete).and_return(answer_message)
      chat.ask_later('Echo "hello" back to me.')

      result = chat.generate

      expect(result).to be(answer_message)
      expect(chat.messages.last).to be(answer_message)
      expect(chat.provider).to have_received(:complete).once
    end
  end

  describe '#run_tools' do
    it 'executes pending tool calls without asking the model, and returns self' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo "hello" back to me.')
      chat.add_message tool_call_message

      expect(chat.run_tools).to be(chat)
      expect(chat.provider).not_to have_received(:complete)
      expect(chat.messages.last.role).to eq(:tool)
      expect(chat.messages.last.content).to eq('hello')
    end

    it 'does nothing when no tool calls are pending' do
      chat.ask_later('Echo "hello" back to me.')

      expect { chat.run_tools }.not_to(change { chat.messages.size })
    end

    it 'executes only the tool calls that have no results yet' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')

      chat.run_tools

      results = chat.messages.select(&:tool_result?)
      expect(results.map(&:tool_call_id)).to eq(%w[call_1 call_2])
      expect(results.last.content).to eq('second')
    end

    it 'does nothing when every tool call in the round is answered' do
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')
      chat.add_message tool_result_message('call_2', 'second')

      expect { chat.run_tools }.not_to(change { chat.messages.size })
    end
  end

  describe '#step' do
    it 'generates when the model owes a response' do
      allow(chat.provider).to receive(:complete).and_return(answer_message)
      chat.ask_later('Echo "hello" back to me.')

      expect(chat.step).to be(answer_message)
    end

    it 'runs tools when the model asked for them' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo "hello" back to me.')
      chat.add_message tool_call_message

      chat.step

      expect(chat.provider).not_to have_received(:complete)
      expect(chat.messages.last.role).to eq(:tool)
    end

    it 'returns nil once the conversation is complete' do
      chat.ask_later('Echo "hello" back to me.')
      chat.add_completion answer_message

      expect(chat.step).to be_nil
    end

    it 'finishes an interrupted tool round before generating' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')

      chat.step

      expect(chat.provider).not_to have_received(:complete)
      expect(chat.messages.count(&:tool_result?)).to eq(2)
    end

    it 'generates once every tool call in the round is answered' do
      allow(chat.provider).to receive(:complete).and_return(answer_message)
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')
      chat.add_message tool_result_message('call_2', 'second')

      expect(chat.step).to be(answer_message)
    end
  end

  describe '#complete' do
    it 'resumes a chat whose last message is an unanswered tool call' do
      allow(chat.provider).to receive(:complete).and_return(answer_message)
      chat.ask_later('Echo "hello" back to me.')
      chat.add_message tool_call_message

      response = chat.complete

      expect(response.content).to eq('hello')
      expect(chat.messages.map(&:role)).to eq(%i[user assistant tool assistant])
      expect(chat.provider).to have_received(:complete).once
    end

    it 'resumes a chat interrupted between tool executions' do
      allow(chat.provider).to receive(:complete).and_return(answer_message)
      chat.ask_later('Echo twice.')
      chat.add_message multi_tool_call_message
      chat.add_message tool_result_message('call_1', 'first')

      response = chat.complete

      expect(response).to be(answer_message)
      expect(chat.messages.map(&:role)).to eq(%i[user assistant tool tool assistant])
      expect(chat.provider).to have_received(:complete).once
    end

    it 'is a no-op on an already-complete chat' do
      allow(chat.provider).to receive(:complete)
      chat.ask_later('Echo "hello" back to me.')
      chat.add_completion answer_message

      expect(chat.complete).to be(answer_message)
      expect(chat.provider).not_to have_received(:complete)
    end
  end

  describe '#add_completion' do
    it 'appends the response and runs message callbacks' do
      received = []
      response = answer_message
      chat.before_message { received << :before }
      chat.after_message { |message| received << message.content }
      chat.ask_later('Echo "hello" back to me.')

      chat.add_completion response

      expect(chat.messages.last).to be(response)
      expect(received).to eq([:before, 'hello'])
    end

    it 'parses JSON content when the chat has a schema' do
      chat.with_schema({ type: 'object', properties: { answer: { type: 'string' } } })
      message = RubyLLM::Message.new(role: :assistant, content: '{"answer":"hello"}')

      chat.add_completion message

      # Content stays the raw JSON string; parsing lives in Message#parsed
      expect(message.content).to eq('{"answer":"hello"}')
      expect(message.parsed).to eq('answer' => 'hello')
    end
  end
end
