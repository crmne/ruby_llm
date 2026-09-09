# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Chat do
  let(:protocol) { RubyLLM::Protocols::Converse.allocate }
  let(:blocks) do
    [
      { 'reasoningContent' => { 'reasoningText' => { 'text' => 'First.', 'signature' => 'sig-one' } } },
      { 'reasoningContent' => { 'redactedContent' => Base64.strict_encode64('encrypted') } },
      { 'reasoningContent' => { 'reasoningText' => { 'text' => '', 'signature' => 'sig-two' } } }
    ]
  end

  def parse_message(content)
    protocol.send(:parse_completion_body,
                  { 'modelId' => model_for(:bedrock), 'output' => { 'message' => { 'content' => content } } }, raw: nil)
  end

  def rendered_content(message)
    JSON.parse(JSON.generate(protocol.send(:format_message_content, message)))
  end

  it 'replays every signed and redacted block in order' do
    content = blocks + [{ 'text' => 'Done.' }]
    message = parse_message(content)

    expect(rendered_content(message)).to eq(content)
    expect(message.thinking.text).to eq('First.')
    expect(message.thinking.signature).to eq('sig-one')
  end

  it 'keeps the complete thinking sequence before local tool calls' do
    content = blocks + [{ 'toolUse' => { 'toolUseId' => 'call-1', 'name' => 'lookup', 'input' => {} } }]

    expect(rendered_content(parse_message(content))).to eq(content)
  end

  it 'replays thinking assembled from multiple streamed blocks' do
    events = [{ 'messageStart' => { 'role' => 'assistant' } }]
    blocks.each_with_index do |block, index|
      content = block.fetch('reasoningContent')
      deltas = if content.key?('reasoningText')
                 content.fetch('reasoningText').map { |key, value| { key => value } }
               else
                 [content]
               end
      deltas.each do |delta|
        events << { 'contentBlockDelta' => { 'contentBlockIndex' => index,
                                             'delta' => { 'reasoningContent' => delta } } }
      end
      events << { 'contentBlockStop' => { 'contentBlockIndex' => index } }
    end
    events << { 'messageStop' => { 'stopReason' => 'end_turn' } }
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    events.each { |event| accumulator.add(protocol.send(:build_chunk, event)) }

    expect(rendered_content(accumulator.to_message(nil))).to eq(blocks)
  end

  it 'does not replay another protocol\'s native thinking blocks' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.',
                                   raw_reasoning: { 'anthropic' => [{ 'type' => 'thinking' }] })

    expect(rendered_content(message)).to eq([{ 'text' => 'Done.' }])
  end

  it 'preserves thinking supplied on a block start' do
    protocol.send(:build_chunk, { 'contentBlockStart' => { 'contentBlockIndex' => 0, 'start' => blocks.first } })
    chunk = protocol.send(:build_chunk, { 'messageStop' => { 'stopReason' => 'end_turn' } })
    message = RubyLLM::Message.new(role: :assistant, content: nil, raw_reasoning: chunk.raw_reasoning)

    expect(rendered_content(message)).to eq([blocks.first])
  end

  it 'joins encrypted byte fragments before encoding the replay block' do
    %w[encr ypted].each do |fragment|
      protocol.send(:build_chunk, { 'contentBlockDelta' => {
                      'contentBlockIndex' => 0,
                      'delta' => { 'reasoningContent' => { 'redactedContent' => Base64.strict_encode64(fragment) } }
                    } })
    end
    chunk = protocol.send(:build_chunk, { 'messageStop' => { 'stopReason' => 'end_turn' } })
    message = RubyLLM::Message.new(role: :assistant, content: nil, raw_reasoning: chunk.raw_reasoning)

    expect(rendered_content(message)).to eq([blocks[1]])
  end

  it 'clears the previous stream\'s thinking before a new response' do
    protocol.send(:build_chunk, { 'contentBlockStart' => { 'contentBlockIndex' => 0, 'start' => blocks.first } })
    protocol.send(:build_chunk, { 'messageStart' => { 'role' => 'assistant' } })

    expect(protocol.send(:build_chunk, { 'messageStop' => { 'stopReason' => 'end_turn' } }).raw_reasoning).to be_nil
  end
end
