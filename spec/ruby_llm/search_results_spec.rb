# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::SearchResults do
  it 'accepts a single result as keywords' do
    results = described_class.new(title: 'Doc', url: 'https://example.com', text: 'Hello')

    expect(results.results).to eq([{ title: 'Doc', url: 'https://example.com', text: 'Hello' }])
  end

  it 'accepts multiple results' do
    results = described_class.new({ title: 'A', text: 'one' }, { title: 'B', text: 'two' })

    expect(results.results.map { |result| result[:title] }).to eq(%w[A B])
  end

  it 'requires at least one result with title and text' do
    expect { described_class.new }.to raise_error(ArgumentError)
    expect { described_class.new(title: 'Doc') }.to raise_error(ArgumentError)
    expect { described_class.new(text: 'Hello') }.to raise_error(ArgumentError)
  end

  it 'serializes to the search_results JSON convention' do
    results = described_class.new(title: 'Doc', url: 'https://example.com', text: 'Hello')

    expect(JSON.parse(results.to_json)).to eq(
      'search_results' => [
        { 'title' => 'Doc', 'url' => 'https://example.com', 'text' => 'Hello' }
      ]
    )
  end

  describe '.from_content' do
    it 'round-trips serialized search results' do
      original = described_class.new(
        { title: 'A', url: 'https://example.com/a', text: 'one' },
        { title: 'B', text: 'two' }
      )

      parsed = described_class.from_content(original.to_json)

      expect(parsed).to be_a(described_class)
      expect(parsed.results).to eq(original.results)
    end

    it 'returns nil for plain text' do
      expect(described_class.from_content('just some tool output')).to be_nil
    end

    it 'returns nil for unrelated JSON' do
      expect(described_class.from_content('{"weather":"sunny"}')).to be_nil
      expect(described_class.from_content('{"search_results":[]}')).to be_nil
    end
  end
end
