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

  it 'renders plain text for providers without citation support' do
    results = described_class.new(title: 'Doc', url: 'https://example.com', text: 'Hello')

    expect(results.text).to eq("<search_result title='Doc' url='https://example.com'>\nHello\n</search_result>")
  end

  it 'requires at least one result with title and text' do
    expect { described_class.new }.to raise_error(ArgumentError)
    expect { described_class.new(title: 'Doc') }.to raise_error(ArgumentError)
  end
end
