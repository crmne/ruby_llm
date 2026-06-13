# frozen_string_literal: true

require 'spec_helper'

class KnowledgeBase < RubyLLM::Tool
  description 'Searches the company knowledge base'
  param :query, desc: 'What to look for'

  def execute(**)
    RubyLLM::SearchResults.new(
      title: 'Ruby Facts',
      url: 'https://example.com/ruby-facts',
      text: 'The Ruby programming language was created by Yukihiro Matsumoto in 1993.'
    )
  end
end

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:facts_path) { File.expand_path('../fixtures/facts.txt', __dir__) }
  let(:pdf_path) { File.expand_path('../fixtures/sample.pdf', __dir__) }

  describe 'citations' do
    context 'with anthropic/claude-haiku-4-5' do
      let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_citations }

      it 'cites text documents in responses' do
        response = chat.ask('Who created Ruby and when? Use the document.', with: facts_path)

        expect(response.citations).not_to be_empty
        citation = response.citations.first
        expect(citation.cited_text).to be_present
        expect(citation.title).to eq('facts.txt')
        expect(citation.source_index).to eq(0)
        expect(response.content[citation.start_index...citation.end_index]).to eq(citation.text)
      end

      it 'cites PDF documents with page numbers' do
        response = chat.ask('What does the document say? Use the document.', with: pdf_path)

        expect(response.citations).not_to be_empty
        citation = response.citations.first
        expect(citation.cited_text).to be_present
        expect(citation.start_page).to be >= 1
      end

      it 'cites tool results returned as search results' do
        chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).with_tool(KnowledgeBase)

        response = chat.ask('Who created Ruby? Search the knowledge base first and cite your sources.')

        expect(response.citations).not_to be_empty
        citation = response.citations.first
        expect(citation.url).to eq('https://example.com/ruby-facts')
        expect(citation.title).to eq('Ruby Facts')
        expect(citation.cited_text).to be_present
        expect(response.content[citation.start_index...citation.end_index]).to eq(citation.text)
      end

      it 'streams citations' do
        chunks = []
        response = chat.ask('Who created Ruby? Use the document.', with: facts_path) do |chunk|
          chunks << chunk
        end

        expect(chunks.any? { |chunk| chunk.citations.any? }).to be true
        expect(response.citations).not_to be_empty
        expect(response.citations.first.cited_text).to be_present
      end
    end

    context 'with perplexity/sonar' do
      it 'returns search result citations' do
        response = RubyLLM.chat(model: 'sonar', provider: :perplexity)
                          .ask('What is the Ruby programming language?')

        expect(response.citations).not_to be_empty
        expect(response.citations.first.url).to be_present
      end

      it 'returns search result citations when streaming' do
        chunks = []
        response = RubyLLM.chat(model: 'sonar', provider: :perplexity)
                          .ask('What is the Ruby programming language?') do |chunk|
          chunks << chunk
        end

        expect(chunks).not_to be_empty
        expect(response.citations).not_to be_empty
        expect(response.citations.first.url).to be_present
      end
    end

    context 'with gemini/gemini-2.5-flash' do
      it 'returns grounding citations when search is enabled' do
        response = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
                          .with_params(tools: [{ google_search: {} }])
                          .ask('What is the latest stable version of Ruby?')

        expect(response.citations).not_to be_empty
        expect(response.citations.first.url).to be_present
      end
    end

    context 'with a model that does not support citations' do
      it 'warns when citations are requested' do
        allow(RubyLLM.logger).to receive(:warn).and_call_original

        response = RubyLLM.chat(model: 'gpt-5-nano', provider: :openai).with_citations.ask('Say hi')

        expect(response.citations).to be_empty
        expect(RubyLLM.logger).to have_received(:warn).with(/does not support citations/)
      end
    end

    context 'with openai/gpt-4o-mini-search-preview' do
      it 'returns url citations when web search is enabled' do
        response = RubyLLM.chat(model: 'gpt-4o-mini-search-preview', provider: :openai)
                          .with_params(web_search_options: {})
                          .ask('What is the latest stable version of Ruby? Cite your sources.')

        expect(response.citations).not_to be_empty
        citation = response.citations.first
        expect(citation.url).to be_present
        expect(response.content[citation.start_index...citation.end_index]).to eq(citation.text) if citation.text
      end
    end
  end
end
