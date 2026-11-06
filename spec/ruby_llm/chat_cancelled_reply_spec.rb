# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  def chunk(content = nil, **attributes)
    RubyLLM::Chunk.new(role: :assistant, content:, **attributes)
  end

  def stream_then_cancel(*chunks)
    allow(chat.provider).to receive(:complete) do |*_args, **_options, &block|
      chunks.each { |part| block.call(part) }
      chat.cancel
      block.call(chunk(' never shown'))
    end
  end

  it 'keeps the text streamed so far as a cancelled assistant message' do
    stream_then_cancel(chunk('Hel'), chunk('lo'))

    expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)

    reply = chat.messages.last
    expect(reply.role).to eq(:assistant)
    expect(reply.content).to eq('Hello')
    expect(reply).to be_cancelled
    expect(reply.finish_reason).to eq(:cancelled)
  end

  it 'announces the partial reply to after_message' do
    replies = []
    chat.after_message { |message| replies << message }
    stream_then_cancel(chunk('Hello'))

    expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)

    expect(replies.map(&:content)).to eq(['Hello'])
  end

  it 'leaves out partial thinking and unfinished tool calls' do
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'lookup', arguments: {})
    stream_then_cancel(chunk(thinking: RubyLLM::Thinking.build(text: 'Let me', signature: 'sig')),
                       chunk('Looking'), chunk(tool_calls: { 'call_1' => call }))

    expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)

    reply = chat.messages.last
    expect(reply.content).to eq('Looking')
    expect(reply.thinking).to be_nil
    expect(reply.tool_calls).to be_empty
  end

  it 'adds nothing when nothing but whitespace streamed' do
    stream_then_cancel(chunk("\n "))

    expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)

    expect(chat.messages.map(&:role)).to eq([:user])
  end

  it 'sends the partial reply with the next question, and is complete until then' do
    stream_then_cancel(chunk('Hello'))
    expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::CancelledError)
    expect(chat).to be_complete

    sent = nil
    allow(chat.provider).to receive(:complete) do |messages, **|
      sent = messages
      RubyLLM::Message.new(role: :assistant, content: 'Sure', input_tokens: 1, output_tokens: 1)
    end
    chat.ask('Go on')

    expect(sent.map { |message| [message.role, message.content] })
      .to eq([[:user, 'Hi'], [:assistant, 'Hello'], [:user, 'Go on']])
  end

  %i[openai anthropic gemini bedrock].each do |slug|
    it "sends the partial reply to #{slug} as an ordinary assistant turn" do
      payload = lambda do |finish_reason|
        provider_chat = described_class.new(model: model_for(slug), provider: slug)
        provider_chat.add_message(role: :user, content: 'Hi')
        provider_chat.add_message(role: :assistant, content: 'Hel', finish_reason:)
        provider_chat.add_message(role: :user, content: 'Go on')
        provider_chat.render
      end

      expect(payload.call(:cancelled)).to eq(payload.call(:stop))
    end
  end

  context 'when a tool round was stopped' do
    let(:tool) do
      stopper = -> { chat.cancel }
      Class.new(RubyLLM::Tool) do
        description 'Stops the chat'
        define_singleton_method(:tool_name) { 'stop' }
        define_method(:execute) do
          stopper.call
          'stopped'
        end
      end
    end
    let(:round) do
      calls = %w[call_1 call_2].to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'stop', arguments: {})] }
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
    end

    before do
      chat.with_tools(tool)
      allow(chat.provider).to receive(:complete).and_return(round)
      begin
        chat.ask('Go')
      rescue RubyLLM::CancelledError
        nil
      end
    end

    it 'marks the closed call and stays stopped' do
      expect(chat.messages.last).to be_cancelled
      expect(chat).to be_complete

      chat.complete

      expect(chat.provider).to have_received(:complete).once
    end

    it 'marks the refusal that closes a remote call' do
      remote = RubyLLM::ToolCall.new(id: 'call_r', name: 'search', arguments: {}, remote: true)
      local = RubyLLM::ToolCall.new(id: 'call_l', name: 'stop', arguments: {})
      refusal = RubyLLM::Message.new(role: :tool, content: 'Denied', tool_call_id: 'call_r')
      allow(chat.provider).to receive_messages(
        complete: RubyLLM::Message.new(role: :assistant, content: '',
                                       tool_calls: { 'call_l' => local, 'call_r' => remote }),
        tool_approval_response: refusal
      )

      expect { chat.ask('Go on') }.to raise_error(RubyLLM::CancelledError)

      expect(chat.messages.last).to be_cancelled
      expect(chat).to be_complete
    end

    it 'goes on with the next question' do
      allow(chat.provider).to receive(:complete).and_return(RubyLLM::Message.new(role: :assistant, content: 'Hi'))

      expect(chat.ask('Again').content).to eq('Hi')
    end
  end
end
