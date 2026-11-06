# frozen_string_literal: true

require 'rails_helper'
require 'socket'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
    server.close
  end

  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:context) do
    port = server.addr[1]
    RubyLLM.context do |config|
      config.anthropic_api_base = "http://127.0.0.1:#{port}"
      config.request_timeout = 1
      config.retry_interval = 0.01
    end
  end
  let(:requests) { Queue.new }

  def ask(text)
    chat.ask(text) { |_chunk| nil }
  end

  def event(name, data)
    "event: #{name}\ndata: #{data.to_json}\n\n"
  end

  def text_events
    event(:message_start, type: 'message_start',
                          message: { id: 'm', type: 'message', role: 'assistant', model: 'claude', content: [],
                                     usage: { input_tokens: 7, output_tokens: 0 } }) +
      event(:content_block_start, type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' }) +
      event(:content_block_delta, type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'Hel' })
  end

  # Answers each request with +reply+, then says nothing more.
  def stall(reply = '')
    Thread.new do
      loop do
        socket = server.accept
        head = socket.gets("\r\n\r\n")
        socket.read(head[/^content-length: (\d+)/i, 1].to_i)
        requests << true
        socket.write("HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n\r\n#{reply}") unless reply.empty?
      end
    rescue IOError, SystemCallError
      nil
    end
  end

  def cancel_during_stall(cancel)
    Thread.new do
      requests.pop
      sleep 0.2
      cancel.call
    end
  end

  def usage_events
    seen = []
    context.config.instrumenter = Class.new do
      define_method(:instrument) do |name, payload = {}, &block|
        seen << payload if name == 'usage.ruby_llm'
        block&.call(payload)
      end
    end.new
    seen
  end

  shared_examples 'a stalled request' do
    it 'stops retrying and raises CancelledError at the timeout' do
      stall
      cancel_during_stall(cancel)

      expect { ask('Hi') }.to raise_error(RubyLLM::CancelledError)
      expect(requests.size).to eq(0)
      expect(chat.messages.to_a.map { |message| message.role.to_sym }).to eq([:user])
    end

    it 'keeps the partial reply when text streamed before the stall' do
      stall(text_events)
      cancel_during_stall(cancel)

      expect { ask('Hi') }.to raise_error(RubyLLM::CancelledError)

      reply = chat.messages.to_a.last
      expect(reply.content).to eq('Hel')
      expect(reply.finish_reason.to_sym).to eq(:cancelled)
    end

    it 'keeps the attempt on the ledger' do
      usage = usage_events
      stall(text_events)
      cancel_during_stall(cancel)

      expect { ask('Hi') }.to raise_error(RubyLLM::CancelledError)

      expect(usage.size).to eq(1)
      expect(usage.first[:tokens].input).to eq(7)
    end

    it 'leaves the chat usable' do
      stall
      cancel_during_stall(cancel)
      expect { ask('Hi') }.to raise_error(RubyLLM::CancelledError)

      llm = chat.respond_to?(:to_llm) ? chat.to_llm : chat
      allow(llm.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Hello', input_tokens: 1, output_tokens: 1))

      expect(chat.ask('Still there?').content).to eq('Hello')
    end
  end

  context 'with a plain chat' do
    let(:chat) { context.chat(model: model_for(:anthropic), provider: :anthropic) }
    let(:cancel) { -> { chat.cancel } }

    it_behaves_like 'a stalled request'

    it 'stops retrying a request that waits for its whole response' do
      stall
      cancel_during_stall(cancel)

      expect { chat.ask('Hi') }.to raise_error(RubyLLM::CancelledError)
      expect(requests.size).to eq(0)
    end

    it 'still raises the timeout on a chat nobody cancelled' do
      stall

      expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ConnectionError)
    end
  end

  context 'with a record cancelled from elsewhere' do
    let(:chat) { Chat.create!(model: model_for(:anthropic)).with_context(context) }
    let(:cancel) do
      id = chat.id
      -> { Chat.connection_pool.with_connection { Chat.where(id:).update_all(cancelled: true) } }
    end

    it_behaves_like 'a stalled request'
  end
end
