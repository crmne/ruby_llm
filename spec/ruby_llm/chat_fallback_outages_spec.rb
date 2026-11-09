# frozen_string_literal: true

require 'spec_helper'
require 'socket'

RSpec.describe RubyLLM::Chat do
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.anthropic_api_key = 'test'
      config.max_retries = 2
      config.retry_interval = 0
      config.retry_interval_randomness = 0
      config.retry_max_interval = 30
    end
  end

  def primary = RubyLLM::Model.default('gpt-4.1-mini', 'openai')

  def stand_in = RubyLLM::Model.default('claude-haiku-4-5', 'anthropic')

  def openai_url = %r{\Ahttps://api\.openai\.com/}

  def anthropic_url = 'https://api.anthropic.com/v1/messages'

  def plain_chat
    context.chat(model: primary.id, provider: :openai, assume_model_exists: true)
  end

  def chat(fallbacks: [stand_in])
    plain_chat.with_fallbacks(*fallbacks)
  end

  def json(body, status: 200, headers: {})
    { status:, headers: { 'Content-Type' => 'application/json' }.merge(headers), body: body.to_json }
  end

  def rate_limited(retry_after = nil, headers: { 'Retry-After' => retry_after })
    json({ error: { message: 'Rate limit reached', type: 'rate_limit_error' } }, status: 429, headers:)
  end

  def openai_text(text)
    json({ id: 'resp_1', object: 'response', status: 'completed', model: primary.id,
           output: [{ type: 'message', id: 'msg_1', role: 'assistant',
                      content: [{ type: 'output_text', text:, annotations: [] }] }],
           usage: { input_tokens: 3, output_tokens: 1, total_tokens: 4 } })
  end

  def anthropic_reply(content, stop_reason: 'end_turn')
    json({ id: 'msg_1', type: 'message', role: 'assistant', model: stand_in.id, content:,
           stop_reason:, usage: { input_tokens: 3, output_tokens: 1 } })
  end

  def anthropic_text(text) = anthropic_reply([{ type: 'text', text: }])

  def anthropic_tool_call
    anthropic_reply([{ type: 'tool_use', id: 'toolu_1', name: 'clock', input: {} }], stop_reason: 'tool_use')
  end

  def second_stand_in = RubyLLM::Model.default('claude-sonnet-4-5', 'anthropic')

  def answers_for(model)
    stub_request(:post, anthropic_url).with(body: hash_including(model: model.id))
  end

  def clock(&on_call)
    Class.new(RubyLLM::Tool) do
      description 'Tells the time'
      def self.tool_name = 'clock'

      define_method(:execute) do
        on_call&.call
        'noon'
      end
    end
  end

  # Retry waits are recorded instead of slept.
  def record_retry_waits
    waits = []
    allow(Faraday::Retry::Middleware).to receive(:new).and_wrap_original do |constructor, *args|
      constructor.call(*args).tap { |middleware| allow(middleware).to receive(:sleep) { |delay| waits << delay } }
    end
    waits
  end

  describe 'a provider that accepts the connection and never answers' do
    let(:silent) { TCPServer.new('127.0.0.1', 0) }
    let(:answering) { TCPServer.new('127.0.0.1', 0) }
    let(:connections) { Queue.new }
    let(:context) do
      silent_port = silent.addr[1]
      answering_port = answering.addr[1]
      RubyLLM.context do |config|
        config.openai_api_key = 'test'
        config.openai_api_base = "http://127.0.0.1:#{silent_port}/v1"
        config.anthropic_api_key = 'test'
        config.anthropic_api_base = "http://127.0.0.1:#{answering_port}"
        config.request_timeout = 0.5
        config.max_retries = 2
        config.retry_interval = 0
        config.retry_interval_randomness = 0
      end
    end

    # Loopback servers, so WebMock (and VCR through it) stays out of the way.
    around do |example|
      WebMock.disable!
      example.run
    ensure
      WebMock.enable!
      [silent, answering].each(&:close)
      connections.size.times { connections.pop.close }
    end

    before do
      Thread.new { serve(silent) { |socket| connections << socket } }
      Thread.new { serve(answering) { |socket| answer(socket) } }
    end

    def serve(server)
      loop { yield server.accept }
    rescue IOError, SystemCallError
      nil
    end

    def answer(socket)
      head = socket.gets("\r\n\r\n")
      socket.read(head[/^content-length: (\d+)/i, 1].to_i)
      body = anthropic_text('Hi')[:body]
      socket.write("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: #{body.bytesize}\r\n" \
                   "connection: close\r\n\r\n#{body}")
      socket.close
    end

    it 'falls back after one timeout when a fallback is left' do
      reply = chat.ask('Hi')

      expect(reply).to have_attributes(content: 'Hi', model: stand_in.id)
      expect(connections.size).to eq(1)
    end

    it 'still retries the same model when no fallback is left' do
      expect { plain_chat.ask('Hi') }.to raise_error(RubyLLM::ConnectionError)
      expect(connections.size).to eq(3)
    end
  end

  describe 'a rate limit' do
    it 'falls back instead of waiting out a long Retry-After' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('20'))
      stub_request(:post, anthropic_url).to_return(anthropic_text('Hi'))

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      reply = chat.ask('Hi')

      expect(reply.model).to eq(stand_in.id)
      expect(openai).to have_been_requested.once
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    end

    it 'falls back instead of waiting out a long hint the provider gives in its own headers' do
      openai = stub_request(:post, openai_url).to_return(rate_limited(headers: { 'retry-after-ms' => '15000' }))
      stub_request(:post, anthropic_url).to_return(anthropic_text('Hi'))

      expect(chat.ask('Hi').model).to eq(stand_in.id)
      expect(openai).to have_been_requested.once
    end

    it 'retries the same model when the wait is short' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('0.1')).then.to_return(openai_text('Hi'))
      fallback = stub_request(:post, anthropic_url)

      reply = chat.ask('Hi')

      expect(reply.model).to eq(primary.id)
      expect(openai).to have_been_requested.twice
      expect(fallback).not_to have_been_requested
    end

    it 'waits on the same model when no fallback is left, as before' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('0.2')).then.to_return(openai_text('Hi'))
      context.config.max_retries = 1

      expect(plain_chat.ask('Hi').content).to eq('Hi')
      expect(openai).to have_been_requested.twice
    end

    it 'retries the same model when the error would not fall back' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('3')).then.to_return(openai_text('Hi'))
      fallback = stub_request(:post, anthropic_url)

      reply = plain_chat.with_fallbacks(stand_in, on: [RubyLLM::ServerError]).ask('Hi')

      expect(reply.model).to eq(primary.id)
      expect(openai).to have_been_requested.twice
      expect(fallback).not_to have_been_requested
    end
  end

  describe 'within one run' do
    it 'stays on the stand-in for the tool round, and the next ask tries the chat model first' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('20'))
      anthropic = stub_request(:post, anthropic_url)
                  .to_return(anthropic_tool_call).then
                  .to_return(anthropic_text('It is noon')).then
                  .to_return(anthropic_text('Still noon'))
      conversation = chat.with_tools(clock)
      fallbacks = []
      conversation.before_fallback { |fallback| fallbacks << [fallback.from.id, fallback.to.id] }

      reply = conversation.ask('What time is it?')

      expect(reply).to have_attributes(content: 'It is noon', model: stand_in.id, provider: 'anthropic')
      expect(conversation.messages.select { |message| message.role == :assistant }.map(&:provider))
        .to eq(%w[anthropic anthropic])
      expect(conversation.messages.select { |message| message.role == :assistant }).to all(be_stood_in)
      expect(openai).to have_been_requested.once
      expect(anthropic).to have_been_requested.twice
      expect(fallbacks).to eq([[primary.id, stand_in.id]])
      expect(conversation.model.id).to eq(primary.id)

      conversation.ask('And now?')

      expect(openai).to have_been_requested.twice
      expect(fallbacks).to eq([[primary.id, stand_in.id]] * 2)
    end

    it 'moves on from a stand-in that fails later in the run, without going back' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('20'))
      first = answers_for(stand_in).to_return(anthropic_tool_call).then.to_return(rate_limited('20'))
      second = answers_for(second_stand_in).to_return(anthropic_text('It is noon'))

      reply = chat(fallbacks: [stand_in, second_stand_in]).with_tools(clock).ask('What time is it?')

      expect(reply.content).to eq('It is noon')
      expect(openai).to have_been_requested.once
      expect(first).to have_been_requested.twice
      expect(second).to have_been_requested.once
    end

    it 'starts on the chat model again once the fallbacks change during the run' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('20'))
      stub_request(:post, anthropic_url).to_return(anthropic_tool_call).then.to_return(anthropic_text('It is noon'))
      conversation = chat
      conversation.with_tools(clock { conversation.with_fallbacks(stand_in) })

      expect(conversation.ask('What time is it?').content).to eq('It is noon')
      expect(openai).to have_been_requested.twice
    end

    it 'treats each generate called directly as a run of its own' do
      openai = stub_request(:post, openai_url).to_return(rate_limited('20'))
      stub_request(:post, anthropic_url).to_return(anthropic_text('Hi'))
      conversation = chat

      2.times { conversation.ask_later('Hi').generate }

      expect(openai).to have_been_requested.twice
      expect(conversation.messages.select { |message| message.role == :assistant }).to all(be_stood_in)
    end

    it 'still retries the last fallback as configured' do
      waits = record_retry_waits
      stub_request(:post, openai_url).to_return(rate_limited('20'))
      anthropic = stub_request(:post, anthropic_url).to_return(rate_limited('20')).then.to_return(anthropic_text('Hi'))

      expect(chat.ask('Hi').content).to eq('Hi')
      expect(anthropic).to have_been_requested.twice
      expect(waits).to eq([20.0])
    end
  end
end
