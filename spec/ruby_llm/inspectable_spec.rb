# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Inspectable do
  include_context 'with configured RubyLLM'

  let(:message) do
    RubyLLM::Message.new(
      role: :assistant,
      content: 'word ' * 50,
      model: 'gpt-4.1-nano',
      input_tokens: 10,
      output_tokens: 20,
      raw: { 'body' => 'x' * 10_000 }
    )
  end

  it 'keeps Message#inspect to one short line without the raw payload' do
    expect(message.inspect.length).to be < 200
    expect(message.inspect).to include('role: :assistant', 'model: "gpt-4.1-nano"')
    expect(message.inspect).not_to include('xxx')
  end

  it 'truncates long values' do
    expect(message.inspect).to include('...')
  end

  it 'makes pretty printing follow #inspect' do
    expect(message.pretty_inspect.chomp).to eq(message.inspect)
  end

  it 'keeps the full dump reachable through #full_inspect' do
    expect(message.full_inspect).to include('@raw')
    expect(message.full_inspect.length).to be > 10_000
  end

  it 'summarizes a Chat without dumping the transcript' do
    chat = RubyLLM.chat(model: 'gpt-4.1-nano')
    chat.add_message(message)

    expect(chat.inspect).to eq('#<RubyLLM::Chat model: "gpt-4.1-nano", provider: "openai", messages: 1>')
  end

  it 'summarizes an Embedding as dimensions, not floats' do
    embedding = RubyLLM::Embedding.new(vectors: Array.new(1536) { 0.1 }, model: 'text-embedding-3-small')

    expect(embedding.inspect).to eq('#<RubyLLM::Embedding model: "text-embedding-3-small", dimensions: 1536>')
  end

  it 'summarizes a Rerank as its model and result count' do
    rerank = RubyLLM::Rerank.new(
      results: [RubyLLM::Rerank::Result.new(index: 0, document: 'Ruby', score: 0.9)],
      model: 'rerank-v3.5'
    )

    expect(rerank.inspect).to eq('#<RubyLLM::Rerank model: "rerank-v3.5", results: 1>')
  end

  it 'omits empty attributes' do
    empty = RubyLLM::Message.new(role: :user, content: '')

    expect(empty.inspect).to eq('#<RubyLLM::Message role: :user>')
  end
end
