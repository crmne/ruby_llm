# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mistral reference citations', :live do # rubocop:disable RSpec/DescribeClass
  let(:lookup) do
    Class.new(RubyLLM::Tool) do
      description 'Find numbered sources about a topic.'
      parameter :topic, type: :string
      define_method(:name) { 'lookup' }
      define_method(:execute) do |topic:|
        _ = topic
        {
          '0' => { url: 'https://example.test/a', title: 'Ruby releases', source: 'example',
                   snippets: [['Ruby 3.4.0 was released on 25 December 2024.']], description: nil, date: nil },
          '1' => { url: 'https://example.test/b', title: 'Ruby 3.4 notes', source: 'example',
                   snippets: [['Prism became the default parser in Ruby 3.4.']], description: nil, date: nil }
        }.to_json
      end
    end
  end
  let(:chat) do
    RubyLLM.chat(model: 'mistral-large-2512', provider: :mistral)
           .with_tools(lookup)
           .with_instructions('Use the lookup tool, then answer and cite the sources you use with reference chunks.')
  end
  let(:question) { 'When was Ruby 3.4.0 released, and what parser became the default?' }

  it 'turns reference chunks into citations pointing at the tool result keys' do
    response = chat.ask(question)

    expect(response.citations).not_to be_empty
    expect(response.citations.map(&:source_index)).to all(be_in([0, 1]))
    expect(response.citations.map(&:start_index)).to all(be_between(0, response.content.length))
  end

  it 'collects reference chunks from a stream' do
    response = chat.ask(question) { |_chunk| nil }

    expect(response.citations).not_to be_empty
    expect(response.citations.map(&:source_index)).to all(be_in([0, 1]))
    expect(response.citations.map(&:start_index)).to all(be_nil)
  end

  describe 'parsing' do
    let(:parser) { RubyLLM::Providers::Mistral::Chat }
    let(:content) do
      [
        { 'type' => 'text', 'text' => 'Released' },
        { 'type' => 'reference', 'reference_ids' => [0, 1] },
        { 'type' => 'text', 'text' => ' in 2024' },
        { 'type' => 'reference', 'reference_ids' => [1] }
      ]
    end

    it 'places each citation after the text before it' do
      citations = parser.reference_citations(content)

      expect(citations.map { |citation| [citation.source_index, citation.start_index, citation.end_index] })
        .to eq([[0, 8, 8], [1, 8, 8], [1, 16, 16]])
    end

    it 'omits offsets on streamed chunks' do
      expect(parser.reference_citations(content, offsets: false).map(&:start_index)).to all(be_nil)
    end

    it 'has no citations for plain text content' do
      expect(parser.reference_citations('Released in 2024')).to eq([])
    end
  end
end
