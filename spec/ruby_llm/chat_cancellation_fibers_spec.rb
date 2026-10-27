# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  it 'stops a tool child fiber at its checkpoint when another thread cancels the chat' do
    ready = Queue.new
    release = Queue.new
    completed = Queue.new
    tool_class = Class.new(RubyLLM::Tool) do
      description 'Waits in a child fiber'
      define_method(:name) { 'nested_wait' }
      define_method(:execute) do
        Fiber.new do
          ready << true
          release.pop
          RubyLLM::Support::Cancellation.check
          completed << :continued
        end.resume
      end
    end
    chat = described_class.new(model: model_for(:openai)).with_tools(tool_class.new)
    call = RubyLLM::ToolCall.new(id: 'call_wait', name: 'nested_wait', arguments: {})
    response = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
    allow(chat.provider).to receive(:complete).and_return(response)
    canceller = Thread.new do
      ready.pop
      chat.cancel
      release << true
    end

    expect { Timeout.timeout(5) { chat.ask('Wait') } }.to raise_error(RubyLLM::CancelledError)
    expect(completed).to be_empty
    expect(chat).not_to be_cancelled
  ensure
    release << true
    ready << true
    canceller&.join
  end

  it 'stops a waiting async tool child when another thread cancels the chat' do
    ready = Queue.new
    release = Queue.new
    completed = Queue.new
    child = nil
    tool_class = Class.new(RubyLLM::Tool) do
      description 'Waits in an async child'
      define_method(:name) { 'async_wait' }
      define_method(:execute) do
        require 'async'
        Sync do |task|
          child = task.async do
            ready << true
            release.pop
            RubyLLM::Support::Cancellation.check
            completed << :continued
          end
          child.wait
        ensure
          child&.stop
        end
      end
    end
    chat = described_class.new(model: model_for(:openai)).with_tools(tool_class.new)
    call = RubyLLM::ToolCall.new(id: 'call_wait', name: 'async_wait', arguments: {})
    response = RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
    allow(chat.provider).to receive(:complete).and_return(response)
    canceller = Thread.new do
      ready.pop
      chat.cancel
      release << true
    end

    expect { Timeout.timeout(5) { chat.ask('Wait') } }.to raise_error(RubyLLM::CancelledError)
    expect(completed).to be_empty
    expect(child).not_to be_alive
    expect(chat).not_to be_cancelled
  ensure
    release << true
    ready << true
    canceller&.join
  end
end
