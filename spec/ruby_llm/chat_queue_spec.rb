# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:events) { [] }
  let(:requests) { [] }
  let(:responses) { [] }
  let(:during_request) { [] }
  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(echo_tool) }

  before do
    allow(chat.provider).to receive(:complete) do |messages, **|
      requests << messages.map { |message| [message.role, message.content.to_s] }
      during_request.shift&.call
      responses.shift || answer('Done')
    end
  end

  def echo_tool
    Class.new(RubyLLM::Tool) do
      description 'Echoes the given text'
      parameter :text, description: 'Text to echo'
      define_method(:name) { 'echo' }
      define_method(:execute) { |text:| text }
    end
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def tool_call(id = 'call_1', text: 'hello')
    RubyLLM::Message.new(
      role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
      tool_calls: { id => RubyLLM::ToolCall.new(id:, name: 'echo', arguments: { 'text' => text }) }
    )
  end

  def transcript
    chat.messages.map { |message| [message.role, message.content.to_s] }
  end

  describe '#queue' do
    it 'stores the message without touching the conversation' do
      queued = chat.queue('Use the EU file', with: 'q3.pdf', owner: :alice)

      expect(queued).to have_attributes(content: 'Use the EU file', attachments: 'q3.pdf', owner: :alice,
                                        steer?: true)
      expect(queued.id).to be_a(String)
      expect(queued.queued_at).to be_a(Time)
      expect(chat.queued_messages).to eq([queued])
      expect(chat.messages).to be_empty
      expect(chat.provider).not_to have_received(:complete)
    end

    it 'lists queued messages oldest first' do
      first = chat.queue('First')
      second = chat.queue('Second', steer: false)

      expect(chat.queued_messages).to eq([first, second])
    end

    it 'leaves the chat complete for a message that waits, and incomplete for one that steers' do
      chat.ask('Hello')
      chat.queue('Later', steer: false)

      expect(chat).to be_complete

      chat.queue('Now')

      expect(chat).not_to be_complete
    end

    it 'runs after_queue with the queued message' do
      chat.after_queue { |queued| events << [:queued, queued.content] }

      chat.queue('Hello')

      expect(events).to eq([[:queued, 'Hello']])
    end

    it 'accepts messages from another thread while the loop runs' do
      started = Queue.new
      queued = Queue.new
      thread = Thread.new do
        started.pop
        chat.queue('From another thread')
        queued << true
      end
      during_request << lambda {
        started << true
        queued.pop
      }

      chat.ask('Hello')
      thread.join

      expect(requests.last).to eq([[:user, 'Hello'], [:assistant, 'Done'], [:user, 'From another thread']])
      expect(chat.queued_messages).to be_empty
    end
  end

  describe 'steering' do
    it 'joins after a round of tool results, before the next request' do
      responses.push(tool_call, answer('Echoed, in the EU'))
      chat.before_tool_call { chat.queue('Use the EU file') }

      chat.ask('Echo hello')

      expect(requests.last).to eq(
        [[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'], [:user, 'Use the EU file']]
      )
      expect(chat.messages.last.content).to eq('Echoed, in the EU')
      expect(chat.queued_messages).to be_empty
    end

    it 'extends a turn whose final answer was being written' do
      responses.push(answer('First answer'), answer('Second answer'))
      during_request << -> { chat.queue('One more thing') }

      response = chat.ask('Hello')

      expect(response.content).to eq('Second answer')
      expect(transcript).to eq(
        [[:user, 'Hello'], [:assistant, 'First answer'], [:user, 'One more thing'], [:assistant, 'Second answer']]
      )
    end

    it 'joins several messages at one boundary as separate user messages, oldest first' do
      during_request << lambda {
        chat.queue('First')
        chat.queue('Second')
      }

      chat.ask('Hello')

      expect(requests.last.last(2)).to eq([[:user, 'First'], [:user, 'Second']])
    end

    it 'runs after_dequeue with the message and the queued message before before_message' do
      chat.after_dequeue { |message, queued| events << [:dequeued, message.role, message.content, queued.content] }
      chat.before_message { events << [:before_message] }
      during_request << -> { chat.queue('Steer') }

      chat.ask('Hello')

      expect(events).to eq([[:before_message], [:dequeued, :user, 'Steer', 'Steer'], [:before_message]])
    end

    it 'is never taken while the chat is waiting, and joins once the round is answered' do
      approved_echo = Class.new(echo_tool) { requires_approval }
      chat.with_tools(nil).with_tools(approved_echo)
      responses.push(tool_call)
      during_request << -> { chat.queue('Steer') }

      chat.ask('Echo hello')

      expect(chat).to be_waiting
      expect(chat.queued_messages.map(&:content)).to eq(['Steer'])
      expect(transcript.last).to eq([:assistant, ''])
      expect { chat.ask_later('Another') }.to raise_error(RubyLLM::PendingToolCallsError)

      chat.approve(chat.pending_approvals.first)
      chat.complete

      expect(requests.last).to eq([[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'], [:user, 'Steer']])
    end
  end

  describe 'steer: false' do
    it 'waits for the turn to end, and the next complete takes it' do
      responses.push(tool_call, answer('First answer'), answer('Second answer'))
      chat.before_tool_call { chat.queue('Afterwards', steer: false) }

      first = chat.ask('Echo hello')

      expect(first.content).to eq('First answer')
      expect(chat).to be_complete
      expect(chat.queued_messages.map(&:content)).to eq(['Afterwards'])

      second = chat.complete

      expect(second.content).to eq('Second answer')
      expect(transcript.last(2)).to eq([[:user, 'Afterwards'], [:assistant, 'Second answer']])
      expect(chat.queued_messages).to be_empty
    end

    it 'is overtaken by steering messages queued after it' do
      during_request << lambda {
        chat.queue('Wait', steer: false)
        chat.queue('Steer')
      }

      chat.ask('Hello')

      expect(transcript).to eq([[:user, 'Hello'], [:assistant, 'Done'], [:user, 'Steer'], [:assistant, 'Done']])
      expect(chat.queued_messages.map(&:content)).to eq(['Wait'])

      chat.complete

      expect(transcript.last(2)).to eq([[:user, 'Wait'], [:assistant, 'Done']])
    end
  end

  describe 'the next ask, complete, or step' do
    it 'takes every queued message, in order, before the new question' do
      chat.ask('Hello')
      chat.queue('Wait', steer: false)
      chat.queue('Steer')

      chat.ask('New question')

      expect(requests.last.drop(2)).to eq([[:user, 'Wait'], [:user, 'Steer'], [:user, 'New question']])
    end

    it 'takes them on a chat with no messages yet' do
      chat.queue('Hello', steer: false)

      expect(chat.complete.content).to eq('Done')
      expect(transcript).to eq([[:user, 'Hello'], [:assistant, 'Done']])
    end

    it 'takes them in a single step' do
      chat.ask('Hello')
      chat.queue('Wait', steer: false)

      expect(chat.step.content).to eq('Done')
      expect(requests.last.last).to eq([:user, 'Wait'])
    end

    it 'keeps a message that fails to join queued, with the ones after it' do
      chat.queue('First')
      chat.queue('Broken', with: 'missing.pdf')
      chat.queue('Last')

      expect { chat.complete }.to raise_error(Errno::ENOENT)
      expect(transcript).to eq([[:user, 'First']])
      expect(chat.queued_messages.map(&:content)).to eq(%w[Broken Last])
    end

    it 'keeps them queued when the chat is cancelled, and takes them after' do
      during_request << lambda {
        chat.queue('Steer')
        chat.queue('Wait', steer: false)
        chat.cancel
      }

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::CancelledError)
      expect(chat.queued_messages.map(&:content)).to eq(%w[Steer Wait])
      expect(transcript).to eq([[:user, 'Hello']])

      chat.complete

      expect(requests.last).to eq([[:user, 'Hello'], [:user, 'Steer'], [:user, 'Wait']])
      expect(chat.queued_messages).to be_empty
    end
  end

  describe '#dup' do
    it 'gives the copy its own queue, which adds to the copy' do
      waiting = chat.queue('Shared')
      copy = chat.dup
      allow(copy.provider).to receive(:complete).and_return(answer('Copied'))

      copy.queue('Copy only')
      copy.complete

      expect(chat.queued_messages).to eq([waiting])
      expect(chat.messages).to be_empty
      expect(copy.messages.map(&:content)).to eq(['Shared', 'Copy only', 'Copied'])
      expect(copy.queued_messages).to be_empty
    end
  end

  describe '#unqueue' do
    it 'takes a message out of the queue and runs after_unqueue' do
      chat.after_unqueue { |queued| events << queued.content }
      queued = chat.queue('Never mind')

      expect(chat.unqueue(queued)).to be(true)
      expect(chat.unqueue(queued.id)).to be(false)
      expect(chat.queued_messages).to be_empty
      expect(events).to eq(['Never mind'])

      chat.complete

      expect(chat.provider).not_to have_received(:complete)
    end

    it 'returns false once the loop took the message' do
      queued = chat.queue('Hello')
      chat.complete

      expect(chat.unqueue(queued)).to be(false)
    end

    it 'lets exactly one of unqueue and the loop win a race' do
      100.times do
        racing = described_class.new(model: model_for(:anthropic))
        allow(racing.provider).to receive(:complete).and_return(answer('Done'))
        queued = racing.queue('Race')
        unqueued = nil
        thread = Thread.new { unqueued = racing.unqueue(queued) }
        racing.step
        thread.join

        taken = racing.messages.count { |message| message.content == 'Race' }
        expect([unqueued, taken]).to eq([true, 0]).or eq([false, 1])
      end
    end
  end
end
