# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::ThinkTags do
  def stream(pieces)
    splitter = described_class.new
    parts = pieces.map { |piece| splitter.feed(piece) } << splitter.finish
    [parts.filter_map(&:first).join, parts.filter_map(&:last).join]
  end

  def split(text)
    described_class.split(text).first(2)
  end

  it 'splits a leading block from the answer' do
    expect(split("<think>reasoning</think>\nanswer")).to eq(%w[answer reasoning])
  end

  it 'counts the characters removed before the answer' do
    expect(described_class.split(" <think>é</think>\nanswer").last).to eq(18)
    expect(described_class.split('<think>unclosed').last).to eq(15)
    expect(described_class.split('plain').last).to eq(0)
  end

  it 'allows whitespace before the opening tag' do
    expect(split(" \n<think>reasoning</think>answer")).to eq(%w[answer reasoning])
  end

  it 'leaves a block after other text in the content' do
    text = "Example:\n<think>x</think> is a tag"

    expect(split(text)).to eq([text, nil])
  end

  it 'treats an unclosed block as thinking' do
    expect(split('<think>cut off reasoning')).to eq([nil, 'cut off reasoning'])
  end

  it 'ends the block at the first closing tag of nested tags' do
    expect(split('<think>a<think>b</think>c</think>d')).to eq(['c</think>d', 'a<think>b'])
  end

  it 'splits only the first of repeated blocks' do
    expect(split('<think>a</think>b<think>c</think>')).to eq(['b<think>c</think>', 'a'])
  end

  it 'keeps an opening tag without its bracket as content' do
    expect(split('<think')).to eq(['<think', nil])
    expect(split('<thinking>x</thinking>y')).to eq(['<thinking>x</thinking>y', nil])
  end

  it 'matches tags case-sensitively' do
    expect(split('<THINK>x</THINK>y')).to eq(['<THINK>x</THINK>y', nil])
    expect(split('<think>x</THINK>y')).to eq([nil, 'x</THINK>y'])
  end

  it 'leaves content alone after more than 64 bytes of leading whitespace' do
    text = "#{' ' * 65}<think>x</think>y"

    expect(split(text)).to eq([text, nil])
    expect(stream(text.chars)).to eq([text, ''])
  end

  it 'never raises on malformed bytes' do
    broken = "\xFF\xFE".dup.force_encoding('UTF-8')

    expect(split("<think>#{broken}</think> #{broken}")).to eq([broken, broken])
    expect(stream(['<thi', broken, 'nk>'])).to eq(["<thi#{broken}nk>", ''])
  end

  it 'agrees with itself however the content is cut' do
    text = " <think>a</think b</think>\n\n answer </think> <think>"

    (1..text.size).each do |size|
      expect(stream(text.chars.each_slice(size).map(&:join))).to eq(split(text).map(&:to_s))
    end
  end

  it 'handles a closing tag split across chunks' do
    expect(stream(['<thi', 'nk>reason', 'ing</th', "ink>\nans", 'wer'])).to eq(%w[answer reasoning])
  end

  it 'streams thinking as it arrives instead of waiting for the closing tag' do
    splitter = described_class.new
    splitter.feed('<think>')
    emitted = +''

    ('a'..'z').each { |letter| emitted << splitter.feed(letter).last.to_s }

    expect(emitted).to eq(('a'..'z').to_a.join)
  end

  it 'holds back no more than a partial tag and the leading whitespace' do
    text = "#{' ' * 64}<think>#{'reasoning ' * 100}</think>#{'answer ' * 100}"
    splitter = described_class.new
    fed = 0
    emitted = 0

    text.each_char do |char|
      content, thinking = splitter.feed(char)
      fed += 1
      emitted += content.to_s.bytesize + thinking.to_s.bytesize
      expect(fed - emitted).to be <= 64 + described_class::OPEN.bytesize + described_class::CLOSE.bytesize
    end
  end

  it 'splits a 10 MB answer' do
    answer = 'x' * (10 * 1024 * 1024)

    expect(split("<think>short</think>#{answer}")).to eq([answer, 'short'])
    expect(split("<think>#{answer}")).to eq([nil, answer])
    expect(split(answer).first).to equal(answer)
  end

  it 'streams one-byte chunks in linear time' do
    time = lambda do |size|
      pieces = "<think>#{'r' * size}</think>#{'a' * size}".chars
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stream(pieces)
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end
    time.call(10_000)

    small = [time.call(25_000), time.call(25_000)].min
    large = [time.call(100_000), time.call(100_000)].min

    expect(large / small).to be < 8
  end
end
