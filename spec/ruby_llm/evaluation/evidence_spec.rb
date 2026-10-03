# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation::Evidence do
  include_context 'with configured RubyLLM'

  let(:call) { RubyLLM::ToolCall.new(id: 'call-1', name: 'lookup_order', arguments: { order_id: 42 }) }
  let(:chat) do
    RubyLLM.chat(model: model_for(:openai)).tap do |conversation|
      conversation.with_instructions('Verify before refunding.')
      conversation.add_message(role: :user, content: 'Refund order 42')
      conversation.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
      conversation.add_message(role: :tool, content: 'Order verified', tool_call_id: call.id)
      conversation.add_message(role: :assistant, content: +'Your refund is approved.', finish_reason: :stop)
    end
  end

  it 'preserves the conversation and tool results without raw provider payloads' do
    evidence = described_class.new(chat)

    expect(evidence.output).to eq('Your refund is approved.')
    expect(evidence.messages.map(&:role)).to eq(%i[system user assistant tool assistant])
    expect(evidence.tool_calls).to eq([call])
    expect(evidence.data[:messages][3]).to include(content: 'Order verified', tool_call_id: 'call-1')
    expect(evidence.data[:complete]).to be(true)
    expect(evidence.data[:messages].last).not_to have_key(:raw_reasoning)
  end

  it 'normalizes an Agent through its existing chat' do
    agent = RubyLLM::Agent.new(chat:)
    expect(described_class.new(agent).data).to eq(described_class.new(chat).data)
  end

  it 'includes only supplied evidence for a standalone Message' do
    evidence = described_class.new(chat.messages.last)

    expect(evidence.messages.size).to eq(1)
    expect(evidence.data[:content]).to eq('Your refund is approved.')
  end

  it 'evaluates requested tool calls without executing them' do
    evidence = described_class.new(call)

    expect(evidence.tool_calls).to eq([call])
    expect(evidence.data).to include(name: 'lookup_order', arguments: { order_id: 42 })
    expect(evidence.data).not_to have_key(:thought_signature)
  end

  it 'recursively handles structured values and typed results' do
    evidence = described_class.new([false, 0, nil, { call:, verdict: RubyLLM::Probability.new(probability: 0.8) }])

    expect(evidence.data.last[:verdict]).to eq(type: 'probability', probability: 0.8)
    expect(evidence.data.first(3)).to eq([false, 0, nil])
    expect(evidence.data).to be_frozen
  end

  it 'does not reinterpret an ordinary string as a file or URL' do
    evidence = described_class.new('https://example.com/private')

    expect(evidence.data).to eq('https://example.com/private')
    expect(evidence.attachments).to be_empty
  end

  it 'preserves attachments separately from textual evidence' do
    attachment = RubyLLM::Attachment.new('https://example.com/receipt.png')
    message = RubyLLM::Message.new(role: :assistant, content: 'Receipt', attachments: [attachment])
    evidence = described_class.new(message)

    expect(evidence.attachments).to eq([attachment])
    expect(evidence.data[:attachments]).to eq([{ attachment: 1, filename: 'receipt.png', content_type: 'image/png' }])
  end

  it 'requires explicit conversion for unsupported objects and detects cycles' do
    object = Object.new
    expect { described_class.new(object) }.to raise_error(ArgumentError, /adapt/)
    evidence = described_class.new(object, adapters: { Object => ->(_value) { 'Converted' } })
    expect(evidence.data).to eq('Converted')
    cycle = []
    cycle << cycle
    expect { described_class.new(cycle) }.to raise_error(ArgumentError, /cycle/)
  end

  it 'snapshots text and evidence before the returned chat changes' do
    evidence = described_class.new(chat)
    chat.messages.last.content.replace('Changed later')
    chat.add_message(role: :user, content: 'Another question')

    expect(evidence.data[:messages].last[:content]).to eq('Your refund is approved.')
    expect(evidence.messages.size).to eq(5)
  end

  it 'preserves incomplete conversation state instead of inventing a final answer' do
    chat.messages.pop
    evidence = described_class.new(chat)

    expect(evidence.data[:complete]).to be(false)
    expect(evidence.data[:messages].last[:role]).to eq('tool')
  end

  it 'distinguishes a change waiting for approval from an executed tool' do
    tool = Class.new(RubyLLM::Tool) do
      requires_approval

      def name
        'lookup_order'
      end

      def execute
        raise 'This tool must not run while collecting evidence'
      end
    end
    chat.with_tools(tool.new)
    chat.messages.pop(2)
    evidence = described_class.new(chat)

    expect(evidence.data).to include(complete: false, waiting: true, pending_approvals: ['call-1'])
    expect(evidence.data[:messages].last[:role]).to eq('assistant')
    expect(evidence.data[:messages].none? { |message| message[:role] == 'tool' }).to be(true)
  end

  it 'keeps transcripts of nested agents distinct' do
    evidence = described_class.new([RubyLLM::Agent.new(chat:), { second: chat }])

    expect(evidence.data.first[:output]).to eq('Your refund is approved.')
    expect(evidence.data.last[:second][:output]).to eq('Your refund is approved.')
  end

  it 'adapts public operation results without provider payloads' do
    transcription = RubyLLM::Transcription.new(text: 'Good morning', model: model_for(:openai, :transcription))
    embedding = RubyLLM::Embedding.new(vectors: [0.25, -0.5], model: model_for(:openai, :embedding))
    moderation = RubyLLM::Moderation::Result.new(flagged: false, categories: [], category_scores: {})

    expect(described_class.new(transcription).data).to include('text' => 'Good morning')
    expect(described_class.new(embedding).data).to include('vectors' => [0.25, -0.5])
    expect(described_class.new(moderation).data).to include('flagged' => false)
  end

  it 'carries media bytes as attachments instead of putting binary data in the prompt' do
    image = RubyLLM::Image.new(data: 'aGVsbG8=', mime_type: 'image/png')
    speech = RubyLLM::Speech.new(data: 'hello', model: model_for(:openai, :speech), mime_type: 'audio/mpeg')

    expect(described_class.new(image).attachments).to eq(['data:image/png;base64,aGVsbG8='])
    expect(described_class.new(speech).attachments).to eq(['data:audio/mpeg;base64,aGVsbG8='])
    expect(described_class.new(speech).data).not_to have_key(:data)
  end

  it 'rejects non-finite numbers and conflicting JSON keys' do
    expect { described_class.new(Float::NAN) }.to raise_error(ArgumentError, /finite/)
    expect { described_class.new({ value: 1, 'value' => 2 }) }.to raise_error(ArgumentError, /Duplicate/)
  end

  it 'preserves native score distributions with integer level indexes' do
    score = RubyLLM::Score.new(score: 0.8, levels: %w[Bad Good], probabilities: { 0 => 0.2, 1 => 0.8 }, confidence: 0.6)
    evidence = described_class.new(score)

    expect(evidence.data[:probabilities]).to eq('0' => 0.2, '1' => 0.8)
    expect { described_class.new({ 0 => 'First', '0' => 'Second' }) }.to raise_error(ArgumentError, /Duplicate/)
  end
end
