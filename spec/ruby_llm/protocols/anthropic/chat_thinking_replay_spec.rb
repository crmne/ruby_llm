# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Chat do
  let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }
  let(:blocks) do
    [
      { 'type' => 'thinking', 'thinking' => 'First.', 'signature' => 'sig-one' },
      { 'type' => 'redacted_thinking', 'data' => 'encrypted' },
      { 'type' => 'thinking', 'thinking' => '', 'signature' => 'sig-two' }
    ]
  end

  def parse_message(content)
    protocol.send(:parse_completion_body,
                  { 'model' => model_for(:anthropic), 'content' => content, 'usage' => {} }, raw: nil)
  end

  def rendered_content(message)
    JSON.parse(JSON.generate(protocol.send(:format_message, message))).fetch('content')
  end

  it 'replays every signed and redacted block in order' do
    content = blocks + [{ 'type' => 'text', 'text' => 'Done.' }]
    message = parse_message(content)

    expect(rendered_content(message)).to eq(content)
    expect(message.thinking.text).to eq('First.')
    expect(message.thinking.signature).to eq('sig-one')
  end

  it 'keeps the complete thinking sequence before local tool calls' do
    content = blocks + [{ 'type' => 'tool_use', 'id' => 'call-1', 'name' => 'lookup', 'input' => {} }]

    expect(rendered_content(parse_message(content))).to eq(content)
  end

  it 'replays thinking assembled from multiple streamed blocks' do
    events = [{ 'type' => 'message_start', 'message' => { 'model' => model_for(:anthropic) } }]
    blocks.each_with_index do |block, index|
      start = block['type'] == 'thinking' ? { 'type' => 'thinking', 'thinking' => '' } : block
      events << { 'type' => 'content_block_start', 'index' => index, 'content_block' => start }
      if block['type'] == 'thinking'
        events << { 'type' => 'content_block_delta', 'index' => index,
                    'delta' => { 'type' => 'thinking_delta', 'thinking' => block['thinking'] } }
        events << { 'type' => 'content_block_delta', 'index' => index,
                    'delta' => { 'type' => 'signature_delta', 'signature' => block['signature'] } }
      end
      events << { 'type' => 'content_block_stop', 'index' => index }
    end
    events << { 'type' => 'message_stop' }
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    events.each { |event| accumulator.add(protocol.send(:build_chunk, event)) }

    expect(rendered_content(accumulator.to_message(nil))).to eq(blocks)
  end

  it 'does not replay another protocol\'s native thinking blocks' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.',
                                   raw_reasoning: { 'converse' => [{ 'reasoningContent' => {} }] })

    expect(rendered_content(message)).to eq([{ 'type' => 'text', 'text' => 'Done.' }])
  end

  it 'clears the previous stream\'s thinking before a new response' do
    protocol.send(:build_chunk, { 'type' => 'content_block_start', 'index' => 0, 'content_block' => blocks.first })
    protocol.send(:build_chunk, { 'type' => 'message_start' })

    expect(protocol.send(:build_chunk, { 'type' => 'message_stop' }).raw_reasoning).to be_nil
  end

  it 'retains the thinking in the final segment of a paused server-tool turn' do
    first = [blocks.first, { 'type' => 'server_tool_use', 'id' => 'server-1', 'name' => 'web_search', 'input' => {} }]
    last = blocks.drop(1) + [{ 'type' => 'text', 'text' => 'Done.' }]

    message = protocol.send(:merge_turn_segments, [parse_message(first), parse_message(last)])

    expect(rendered_content(message)).to eq(first + last)
  end
end
