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

    it 'runs after_join with the message and the queued message before before_message' do
      chat.after_join { |message, queued| events << [:joined, message.role, message.content, queued.content] }
      chat.before_message { events << [:before_message] }
      during_request << -> { chat.queue('Steer') }

      chat.ask('Hello')

      expect(events).to eq([[:before_message], [:joined, :user, 'Steer', 'Steer'], [:before_message]])
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

  describe 'a resumed turn' do
    it 'takes only steering messages when it resumes after an approval' do
      approved_echo = Class.new(echo_tool) { requires_approval }
      chat.with_tools(nil).with_tools(approved_echo)
      responses.push(tool_call, answer('Echoed'))
      during_request << lambda {
        chat.queue('Afterwards', steer: false)
        chat.queue('Steer')
      }

      chat.ask('Echo hello')
      chat.approve(chat.pending_approvals.first)
      response = chat.complete

      expect(response.content).to eq('Echoed')
      expect(requests.last).to eq([[:user, 'Echo hello'], [:assistant, ''], [:tool, 'hello'], [:user, 'Steer']])
      expect(chat.queued_messages.map(&:content)).to eq(['Afterwards'])
      expect(chat).to be_complete
    end

    it 'takes only steering messages when it resumes after its tool results' do
      responses.push(tool_call)
      chat.ask_later('Echo hello').step
      chat.step
      chat.queue('Afterwards', steer: false)

      chat.complete

      expect(transcript.last).to eq([:assistant, 'Done'])
      expect(chat.queued_messages.map(&:content)).to eq(['Afterwards'])
    end
  end

  describe '#around_join' do
    it 'wraps each join, and join.call returns the message it added' do
      chat.around_join do |queued, join|
        events << [:before, queued.content, chat.messages.size]
        message = join.call
        events << [:after, message.role, message.content]
      end
      chat.after_join { |message, _queued| events << [:joined, message.content] }
      chat.queue('Steer')

      chat.complete

      expect(events).to eq([[:before, 'Steer', 0], [:after, :user, 'Steer'], [:joined, 'Steer']])
      expect(transcript).to eq([[:user, 'Steer'], [:assistant, 'Done']])
    end

    it 'nests several callbacks in the order they were registered' do
      chat.around_join do |_queued, join|
        events << :outer_before
        events << [:outer_got, join.call.content]
      end
      chat.around_join do |_queued, join|
        events << :inner_before
        join.call
        events << :inner_after
      end
      chat.queue('Hello')

      chat.complete

      expect(events).to eq([:outer_before, :inner_before, :inner_after, [:outer_got, 'Hello']])
      expect(transcript.count { |role, content| role == :user && content == 'Hello' }).to eq(1)
    end

    it 'withdraws a message whose callback never joins it, and the turn goes on' do
      chat.around_join { |queued, join| join.call unless queued.content == 'Never mind' }
      chat.after_unqueue { |queued| events << [:unqueued, queued.content] }
      chat.after_join { |message, _queued| events << [:joined, message.content] }
      chat.queue('Never mind')
      chat.queue('Keep this')

      response = chat.complete

      expect(response.content).to eq('Done')
      expect(transcript).to eq([[:user, 'Keep this'], [:assistant, 'Done']])
      expect(events).to eq([[:unqueued, 'Never mind'], [:joined, 'Keep this']])
      expect(chat.queued_messages).to be_empty
    end

    it 'keeps the message queued and out of the conversation when the callback raises' do
      chat.around_join do |_queued, join|
        join.call
        raise IOError, 'audit failed'
      end
      chat.queue('Hello')

      expect { chat.complete }.to raise_error(IOError)
      expect(chat.messages).to be_empty
      expect(chat.queued_messages.map(&:content)).to eq(['Hello'])
      expect(chat.provider).not_to have_received(:complete)
    end

    it 'rejects attributes for join on a plain chat' do
      chat.around_join { |queued, join| join.call(sender: queued.owner) }
      chat.queue('Hello', owner: :alice)

      expect { chat.complete }.to raise_error(ArgumentError, /persisted chat/)
      expect(chat.queued_messages.map(&:content)).to eq(['Hello'])
    end

    it 'registers the same block once' do
      callback = proc do |_queued, join|
        events << :around
        join.call
      end
      chat.around_join(&callback).around_join(&callback)
      chat.queue('Hello')

      chat.complete

      expect(events).to eq([:around])
    end
  end

  describe '#join_queued_messages' do
    it 'joins every queued message without asking the model, and returns them' do
      chat.around_join do |_queued, join|
        events << :around
        join.call
      end
      chat.after_join { |message, _queued| events << [:joined, message.content] }
      chat.queue('Steer')
      chat.queue('Wait', steer: false)

      joined = chat.join_queued_messages

      expect(joined).to all(be_a(RubyLLM::Message))
      expect(joined.map(&:content)).to eq(%w[Steer Wait])
      expect(events).to eq([:around, [:joined, 'Steer'], :around, [:joined, 'Wait']])
      expect(transcript).to eq([[:user, 'Steer'], [:user, 'Wait']])
      expect(chat.queued_messages).to be_empty
      expect(chat.provider).not_to have_received(:complete)
    end

    it 'leaves out a message an around_join withdrew' do
      chat.around_join { |queued, join| join.call if queued.steer? }
      chat.queue('Steer')
      chat.queue('Wait', steer: false)

      expect(chat.join_queued_messages.map(&:content)).to eq(['Steer'])
      expect(chat.queued_messages).to be_empty
    end

    it 'returns an empty list when nothing is queued' do
      expect(chat.join_queued_messages).to eq([])
    end

    it 'raises while tool calls are pending' do
      approved_echo = Class.new(echo_tool) { requires_approval }
      chat.with_tools(nil).with_tools(approved_echo)
      responses.push(tool_call)
      chat.ask('Echo hello')
      chat.queue('Steer')

      expect { chat.join_queued_messages }.to raise_error(RubyLLM::PendingToolCallsError)
      expect(chat.queued_messages.map(&:content)).to eq(['Steer'])
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

    it 'waits through a complete that answers the question ask_later staged' do
      chat.ask_later('Summarize Q3')
      chat.queue('Then email it', steer: false)

      expect(chat.complete.content).to eq('Done')
      expect(requests).to eq([[[:user, 'Summarize Q3']]])
      expect(chat).to be_complete
      expect(chat.queued_messages.map(&:content)).to eq(['Then email it'])
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
    it 'runs after_join for a message that joined before a later one failed' do
      joined = []
      chat.after_join { |message, _queued| joined << message.content }
      chat.queue 'First'
      chat.queue 'Second'
      allow(chat).to receive(:add_message).and_wrap_original do |add, **options|
        raise IOError, 'storage is down' if options[:content] == 'Second'

        add.call(**options)
      end

      expect { chat.ask 'Hello' }.to raise_error(IOError)
      expect(joined).to eq(['First'])
      expect(chat.queued_messages.map(&:content)).to eq(['Second'])
    end

    it 'keeps later messages queued, and the joined one out, when after_join raises' do
      chat.after_join { |_message, _queued| raise IOError, 'callback failed' }
      chat.queue 'First'
      chat.queue 'Second'

      expect { chat.ask 'Hello' }.to raise_error(IOError)
      expect(chat.queued_messages.map(&:content)).to eq(['Second'])
    end

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

    it 'keeps them queued when the chat is cancelled, and the turn takes the steering ones after' do
      during_request << lambda {
        chat.queue('Steer')
        chat.queue('Wait', steer: false)
        chat.cancel
      }

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::CancelledError)
      expect(chat.queued_messages.map(&:content)).to eq(%w[Steer Wait])
      expect(transcript).to eq([[:user, 'Hello']])

      chat.complete

      expect(requests.last).to eq([[:user, 'Hello'], [:user, 'Steer']])
      expect(chat.queued_messages.map(&:content)).to eq(['Wait'])
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

    it 'gives the copy the around_join callbacks, and keeps its own to itself' do
      chat.around_join do |_queued, join|
        events << :shared
        join.call
      end
      copy = chat.dup
      copy.around_join do |_queued, join|
        events << :copy_only
        join.call
      end
      allow(copy.provider).to receive(:complete).and_return(answer('Copied'))

      chat.queue('Original')
      chat.join_queued_messages
      copy.queue('Copy')
      copy.join_queued_messages

      expect(events).to eq(%i[shared shared copy_only])
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
