# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::CitationMarkers do
  let(:marker) { "\u{E200}cite\u{E202}turn0view0\u{E202}turn1view0\u{E201}" }

  it 'removes whole markers and maps indices past them' do
    text, markers = described_class.strip("A #{marker}B #{marker}C")

    expect(text).to eq('A B C')
    expect([markers.shift(2), markers.shift(3 + marker.length), markers.shift(5 + (2 * marker.length))])
      .to eq([2, 3, 5])
  end

  it 'leaves text without markers alone' do
    expect(described_class.strip('Plain answer').first).to eq('Plain answer')
  end

  it 'drops stray marker characters' do
    text, markers = described_class.strip("\u{E201}kept\u{E202}")

    expect(text).to eq('kept')
    expect(markers.shift(5)).to eq(4)
  end

  it 'drops a marker cut off at the end of the text' do
    expect(described_class.strip("Done. \u{E200}cite\u{E202}turn0").first).to eq('Done. ')
  end

  it 'keeps the words after an opening character that never closes' do
    expect(described_class.strip("Odd \u{E200}text here").first).to eq('Odd text here')
    expect(described_class.strip("\u{E200}a \u{E200}b\u{E201}c").first).to eq('a c')
  end

  it 'keeps a word after an opening character that ends the text without a citation' do
    expect(described_class.strip("Label \u{E200}report").first).to eq('Label report')
    expect(described_class.strip("Done. \u{E200}ci").first).to eq('Done. ')
  end

  it 'stops holding text once it is longer than any marker' do
    markers = described_class.new
    long = 'x' * described_class::MAX_LENGTH

    expect(markers.feed("\u{E200}")).to be_nil
    expect(markers.feed(long)).to eq(long)
    expect(markers.finish).to be_nil
  end
end
