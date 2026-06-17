# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Citation do
  let(:attributes) do
    {
      url: 'https://example.com',
      title: 'Example',
      cited_text: 'The grass is green.',
      text: 'the grass is green',
      start_index: 28,
      end_index: 46,
      source_index: 0,
      start_page: 5,
      end_page: 5
    }
  end

  it 'round-trips through to_h and from_h' do
    citation = described_class.new(attributes)

    expect(citation.to_h).to eq(attributes)
    expect(described_class.from_h(citation.to_h)).to eq(citation)
  end

  it 'builds from string-keyed hashes' do
    citation = described_class.from_h({ 'url' => 'https://example.com', 'start_index' => 3 })

    expect(citation.url).to eq('https://example.com')
    expect(citation.start_index).to eq(3)
  end

  it 'omits missing fields from to_h' do
    citation = described_class.new(url: 'https://example.com')

    expect(citation.to_h).to eq(url: 'https://example.com')
  end

  it 'compares by value' do
    citation = described_class.new(attributes)
    twin = described_class.new(attributes.dup)

    expect(citation).to eq(twin)
    expect(citation).not_to eq(described_class.new(attributes.merge(url: 'https://other.com')))
  end
end
