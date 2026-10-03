# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::RequestShapes::Analysis do
  def part(kind, **attributes)
    RubyLLM::Protocol::RequestShapes::PartSpec.new(kind:, **attributes)
  end

  def text
    part(:text, measure: 5)
  end

  def call(name, id: nil, signed: false)
    part(:tool_call, name:, call_id: id, measure: 2, signed:)
  end

  def result(name: nil, id: nil)
    part(:tool_result, name:, result_id: id, measure: 9)
  end

  def turn(index, speaker, *parts)
    RubyLLM::Protocol::RequestShapes::TurnSpec.new(index:, role: speaker.to_s, speaker:, parts:)
  end

  def problems(turns, pairing: :id, rules: [])
    described_class.new(turns, pairing:, rules:).problems.map { |problem| problem.to_h.except(:message) }
  end

  it 'pairs results with calls by id, names them after their calls, and shows the id of a result with no call' do
    turns = [turn(0, :user, text), turn(1, :model, call('lookup', id: 'a'), call('fetch', id: 'b')),
             turn(2, :tool, result(id: 'b'), result(id: 'a')), turn(3, :model, call('lookup', id: 'c')),
             turn(4, :tool, result(id: 'z'))]
    analysis = described_class.new(turns, pairing: :id, rules: [])

    expect(analysis.tool_rounds.map(&:to_h)).to eq([{ turn: 1, calls: 2, results: 2, paired: true },
                                                    { turn: 3, calls: 1, results: 1, paired: false }])
    expect(turns[2].parts.map(&:name)).to eq(%w[fetch lookup])
    expect(analysis.problems.map(&:to_s)).to eq(
      ['problem at #3: 1 call and 1 result that do not pair up',
       'problem at #4, part 0: result answers no call in the request (call id z)']
    )
  end

  it 'pairs results with calls by position and name where the provider sends no ids' do
    turns = [turn(0, :user, text), turn(1, :model, call('lookup'), call('fetch')),
             turn(2, :tool, result(name: 'fetch'), result(name: 'lookup')), turn(3, :model, call('lookup'))]

    expect(described_class.new(turns, pairing: :position, rules: []).problems.map(&:to_s)).to eq(
      ['problem at #1: 2 calls and 2 results that do not pair up', 'problem at #3: 1 call but 0 results']
    )
  end

  it 'counts the model calls of the current turn' do
    turns = [turn(0, :user, text), turn(1, :model, call('a', id: '1')), turn(2, :tool, result(id: '1')),
             turn(3, :model, call('a', id: '2')), turn(4, :tool, result(id: '2'))]

    expect(described_class.new(turns, pairing: :id, rules: []).step).to eq(3)
    expect(described_class.new([turn(0, :model, text)], pairing: :id, rules: []).step).to be_nil
  end

  it 'wants the first call of each step in the current turn signed, when the protocol requires it' do
    turns = [turn(0, :user, text), turn(1, :model, call('a')), turn(2, :tool, result(name: 'a')),
             turn(3, :user, text), turn(4, :model, call('a', signed: true), call('b')),
             turn(5, :tool, result(name: 'a'), result(name: 'b')), turn(6, :model, text, call('c'))]

    expect(problems(turns, pairing: :position, rules: %i[signed_steps]))
      .to eq([{ kind: :unpaired_round, turn: 6 }, { kind: :unsigned_call, turn: 6, part: 1 }])
  end

  it 'finds parts with no data, empty turns, unsigned thinking, and roles out of order' do
    turns = [turn(0, :system, text), turn(1, :model, part(:thinking, measure: 4)), turn(2, :user),
             turn(3, :user, part(:thinking, signed: true, without_data: true))]

    expect(problems(turns, rules: %i[signed_thinking alternating_roles])).to eq(
      [{ kind: :role_order, turn: 1 }, { kind: :unsigned_thinking, turn: 1, part: 0 }, { kind: :empty_turn, turn: 2 },
       { kind: :role_order, turn: 3 }, { kind: :part_without_data, turn: 3, part: 0 }]
    )
  end

  it 'keeps the first 10 and last 50 turns of a long conversation, and finds problems in all of them' do
    turns = (0..69).map { |index| turn(index, index.odd? ? :model : :user, text) }
    turns[31] = turn(31, :model, call('lookup', id: 'x'))
    analysis = described_class.new(turns, pairing: :id, rules: [])

    expect(analysis.kept_turns.map(&:index)).to eq([*0..9, *20..69])
    expect(analysis.tool_rounds.map(&:turn)).to eq([31])
    expect(analysis.problems.map(&:turn)).to eq([31])
  end
end
