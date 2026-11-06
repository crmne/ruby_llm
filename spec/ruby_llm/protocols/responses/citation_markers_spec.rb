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
    expect(described_class.strip("Done. \u{E200}cite\u{E202}turn0").first).to eq('Done.')
  end

  it 'keeps the words after an opening character that never closes' do
    expect(described_class.strip("Odd \u{E200}text here").first).to eq('Odd text here')
    expect(described_class.strip("\u{E200}a \u{E200}b\u{E201}c").first).to eq('a bc')
  end

  it 'keeps a word after an opening character that ends the text without a citation' do
    expect(described_class.strip("Label \u{E200}report").first).to eq('Label report')
    expect(described_class.strip("Done. \u{E200}ci").first).to eq('Done.')
  end

  it 'keeps the text of a closed pair that holds no citation' do
    text, markers = described_class.strip("Label \u{E200}report\u{E201} end")

    expect(text).to eq('Label report end')
    expect(markers.shift(8)).to eq(7)
  end

  it 'keeps a pair that has the shape of a marker but cites nothing' do
    expect(described_class.strip("Label \u{E200}report\u{E202}draft\u{E201}").first).to eq('Label reportdraft')
    expect(described_class.strip("Done. \u{E200}cite\u{E202}tu").first).to eq('Done.')
  end

  it 'removes a citation with a line locator' do
    expect(described_class.strip("Notes. \u{E200}cite\u{E202}turn0file0\u{E202}L8-L13\u{E201} End").first)
      .to eq('Notes. End')
    expect(described_class.strip("Cut \u{E200}cite\u{E202}turn0file0\u{E202}L8-").first).to eq('Cut')
  end

  it 'removes a citation of an injected block, whose id has no turn' do
    expect(described_class.strip("Held. \u{E200}cite\u{E202}block5\u{E201} End").first).to eq('Held. End')
  end

  it 'keeps a closed pair whose reference is empty or not an id' do
    expect(described_class.strip("A \u{E200}cite\u{E202}\u{E201} B").first).to eq('A cite B')
    expect(described_class.strip("A \u{E200}cite\u{E202}two words\u{E201} B").first).to eq('A citetwo words B')
  end

  it 'takes the space before a marker when punctuation, a space, or the end follows' do
    text, markers = described_class.strip("urgent #{marker}. Next")

    expect(text).to eq('urgent. Next')
    expect(markers.shift(7 + marker.length)).to eq(6)
    expect(described_class.strip("one #{marker} two #{marker}").first).to eq('one two')
  end

  it 'keeps the space before a marker when a word follows' do
    expect(described_class.strip("one #{marker}two").first).to eq('one two')
  end

  it 'keeps spaces that have no marker after them' do
    expect(described_class.strip('Trailing space ').first).to eq('Trailing space ')
    expect(described_class.strip('a , b').first).to eq('a , b')
  end

  it 'takes the space before a marker across stream chunks' do
    stream = described_class.new
    chunks = ["urgent #{marker[0, 3]}", marker[3..], '.'].map { |chunk| stream.feed(chunk) }

    expect("#{chunks.join}#{stream.finish}").to eq('urgent.')
  end

  it 'takes the space before a marker when the next chunk brings the punctuation' do
    stream = described_class.new
    chunks = ["urgent #{marker}", '. Next'].map { |chunk| stream.feed(chunk) }

    expect(chunks).to eq(['urgent', '. Next'])
  end

  it 'sends a space that ends a chunk with no marker in that chunk' do
    expect(described_class.new.feed('Done. ')).to eq('Done. ')
  end

  it 'removes other markers built the same way' do
    expect(described_class.strip("See \u{E200}filecite\u{E202}turn0file0\u{E201}.").first).to eq('See.')
  end

  it 'stops holding text once it is longer than any marker' do
    markers = described_class.new
    long = 'x' * described_class::MAX_LENGTH

    expect(markers.feed("\u{E200}")).to be_nil
    expect(markers.feed(long)).to eq(long)
    expect(markers.finish).to be_nil
  end
end
