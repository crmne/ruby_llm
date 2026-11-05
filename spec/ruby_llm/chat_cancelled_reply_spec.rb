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
end
