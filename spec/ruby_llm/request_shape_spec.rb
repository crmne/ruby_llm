# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::RequestShape do
  def part(...)
    RubyLLM::RequestShape::Part.new(...)
  end

  def turn(...)
    RubyLLM::RequestShape::Turn.new(...)
  end

  let(:shape) do
    described_class.new(
      provider: 'gemini', model: 'gemini-2.5-flash', step: 3,
      payload_keys: %w[contents generationConfig tools], thinking_settings: { 'thinkingBudget' => -1 },
      instructions: [part(kind: :text, size: 240)],
      turns: [
        turn(index: 0, role: 'user', parts: [part(kind: :text, size: 17)]),
        turn(index: 1, role: 'model',
             parts: [part(kind: :thinking, signed: true), part(kind: :tool_call, name: 'find_tasks', size: 42)]),
        turn(index: 2, role: 'user', parts: [part(kind: :tool_result, name: 'find_tasks', size: 6859)]),
        turn(index: 70, role: 'user', parts: [part(kind: :image, size: 1, unit: :bytes, source: :inline,
                                                   mime_type: 'image/png')])
      ],
      turn_count: 71, omitted_turns: 67, tool_names: %w[find_tasks],
      tool_rounds: [RubyLLM::RequestShape::ToolRound.new(turn: 1, calls: 1, results: 1, paired: true)],
      problems: [RubyLLM::RequestShape::Problem.new(kind: :part_without_data, turn: 1, part: 0,
                                                    message: 'thinking part carries no data')]
    )
  end

  describe '#to_s' do
    it 'spells out the request, one turn per line, with units' do
      expect(shape.to_s).to eq(<<~SHAPE.chomp)
        gemini, gemini-2.5-flash, model call 3 of the turn, after 2 tool rounds
        payload keys: contents, generationConfig, tools
        thinking: thinkingBudget -1
        instructions: text (240 chars)
        #0 user: text (17 chars)
        #1 model: thinking (no text), signed, call find_tasks (args 42 chars)
        #2 user: result find_tasks (6859 chars)
        (67 turns omitted)
        #70 user: image/png (1 byte)
        tools: find_tasks
        tool round at #1: 1 call, 1 result, paired
        problem at #1, part 0: thinking part carries no data
      SHAPE
    end

    it 'says when it finds no problems, and leaves out what the request does not send' do
      shape = described_class.new(turns: [turn(index: 0, role: nil, parts: [])], step: 1)

      expect(shape.to_s).to eq("model call 1 of the turn\n#0: no parts\nno problems found")
    end
  end

  describe '#to_h' do
    it 'keeps the same keys whatever the request sends' do
      keys = %i[provider model step payload_keys thinking_settings instructions turn_count omitted_turns turns
                tool_names tool_rounds problems]

      expect(shape.to_h.keys).to eq(keys)
      expect(described_class.new(turns: []).to_h).to eq(
        provider: nil, model: nil, step: nil, payload_keys: [], thinking_settings: {}, instructions: [],
        turn_count: 0, omitted_turns: 0, turns: [], tool_names: [], tool_rounds: [], problems: []
      )
    end

    it 'describes every turn, round, and problem, with sizes under their units' do
      expect(shape.to_h).to include(
        provider: 'gemini', model: 'gemini-2.5-flash', step: 3, turn_count: 71, omitted_turns: 67,
        tool_rounds: [{ turn: 1, calls: 1, results: 1, paired: true }],
        problems: [{ kind: :part_without_data, turn: 1, part: 0, message: 'thinking part carries no data' }]
      )
      expect(shape.to_h[:turns][1]).to eq(
        index: 1, role: 'model',
        parts: [{ kind: :thinking, signed: true }, { kind: :tool_call, name: 'find_tasks', chars: 42 }]
      )
      expect(shape.to_h[:turns].last[:parts]).to eq([{ kind: :image, bytes: 1, source: :inline,
                                                       mime_type: 'image/png' }])
    end
  end

  describe '#inspect' do
    it 'summarizes the shape on one line' do
      expect(shape.inspect)
        .to eq('#<RubyLLM::RequestShape provider: "gemini", model: "gemini-2.5-flash", turns: 71, problems: 1>')
      expect(shape.turns.first.inspect)
        .to eq('#<RubyLLM::RequestShape::Turn index: 0, role: "user", parts: "text (17 chars)">')
    end
  end

  describe RubyLLM::RequestShape::Part do
    it 'names media by its MIME type, or by its kind and where it comes from' do
      expect(part(kind: :document, size: 120, unit: :bytes, source: :inline, mime_type: 'application/pdf').to_s)
        .to eq('application/pdf (120 bytes)')
      expect(part(kind: :image, source: :url).to_s).to eq('image (url)')
      expect(part(kind: :document, source: :file, mime_type: 'application/pdf').to_s)
        .to eq('application/pdf (file)')
      expect(part(kind: :audio, source: :inline).to_s).to eq('audio (no data)')
    end

    it 'names calls, results, and pieces RubyLLM does not classify' do
      call = part(kind: :tool_call, name: 'lookup', size: 1, signed: true)

      expect(call.to_s).to eq('call lookup (args 1 char), signed')
      expect(part(kind: :tool_result, size: 7).to_s).to eq('result (7 chars)')
      expect(part(kind: :other, name: 'cachePoint').to_s).to eq('cachePoint')
      expect(part(kind: :other).to_s).to eq('part of no known kind')
    end

    it 'reports whether it is signed' do
      expect(part(kind: :text, size: 3, signed: true)).to be_signed
      expect(part(kind: :text, size: 3)).not_to be_signed
      expect(part(kind: :text, size: 3).to_h).to eq(kind: :text, chars: 3)
    end
  end

  describe RubyLLM::RequestShape::ToolRound do
    it 'counts calls and results, and says whether they pair up' do
      round = described_class.new(turn: 4, calls: 2, results: 1, paired: false)

      expect(round.to_s).to eq('tool round at #4: 2 calls, 1 result, not paired')
      expect(round).not_to be_paired
    end
  end

  describe RubyLLM::RequestShape::Problem do
    it 'names the one id a shape shows, and where the problem is' do
      problem = described_class.new(kind: :unmatched_result, turn: 6, part: 0, call_id: 'toolu_01',
                                    message: 'result answers no call in the request')

      expect(problem.to_s).to eq('problem at #6, part 0: result answers no call in the request (call id toolu_01)')
      expect(described_class.new(kind: :empty_turn, turn: 2, message: 'turn has no parts').to_s)
        .to eq('problem at #2: turn has no parts')
    end
  end
end
