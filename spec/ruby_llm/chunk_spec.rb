# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunk do
  include_context 'with configured RubyLLM'

  let(:tool) do
    Class.new(RubyLLM::Tool) do
      def self.name = 'LookupTool'
      description 'Looks something up'
      parameter :query, description: 'What to look up'

      def execute(query:) = "Found #{query}"
    end
  end

  let(:chat) { RubyLLM::Chat.new(model: model_for(:anthropic)).with_tools(tool) }

  def chunk(content = nil, **attributes)
    described_class.new(role: :assistant, content: content, **attributes)
  end

  def stream(chunks, response, &block)
    chunks.each { |item| block.call(item) }
    response
  end

  it 'numbers the chunks of each response from 0, starting again after a tool call' do
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'lookup', arguments: { 'query' => 'blocks' })
    responses = [
      [[chunk, chunk(tool_calls: { 'call_1' => call })],
       RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call })],
      [[chunk('Ruby '), chunk('blocks'), chunk],
       RubyLLM::Message.new(role: :assistant, content: 'Ruby blocks')]
    ]
    allow(chat.provider).to receive(:complete) { |*, **, &block| stream(*responses.shift, &block) }

    streamed = []
    chat.ask('What are blocks?') { |item| streamed << [item.content.to_s, item.index] }

    expect(streamed).to eq([['', 0], ['', 1], ['Ruby ', 0], ['blocks', 1], ['', 2]])
  end

  it 'has no index outside a stream' do
    expect(chunk('text').index).to be_nil
  end
end
