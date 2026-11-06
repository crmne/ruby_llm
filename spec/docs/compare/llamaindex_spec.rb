# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and LlamaIndex guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/llamaindex.md' }
  let(:embedded) { [] }
  let(:searches) { [] }

  def model = doc_model('anthropic_latest')
  def answer = 'Return it within 30 days.'
  def policy = 'Return any jacket within 30 days.'

  # The page's Article uses the neighbor gem, which RubyLLM does not depend on,
  # so its two calls are stubbed and the rest is a real Active Record model.
  before do
    ActiveRecord::Base.connection.create_table(:articles, temporary: true, force: true) do |t|
      t.string :title
      t.text :body
      t.json :embedding
    end
    allow(ApplicationRecord).to receive(:has_neighbors)
    allow(ApplicationRecord).to receive(:nearest_neighbors) do |_column, vector, distance:|
      searches << [vector, distance]
      Article.order(:id)
    end
    stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return do |request|
      embedded.concat(Array(JSON.parse(request.body)['input']))
      json_reply(model: doc_model('embedding_small'), data: [{ embedding: [0.1, 0.2] }],
                 usage: { prompt_tokens: 3, total_tokens: 3 })
    end
  end

  after { ActiveRecord::Base.connection.drop_table(:articles, if_exists: true) }

  it 'answers from a folder through a read-only file store' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'data'))
      File.write(File.join(dir, 'data', 'essay.txt'), "The author wrote short stories growing up.\n")
      stub_anthropic(tool_turn('search_files', query: 'grow'), 'He wrote short stories.')

      expect { Dir.chdir(dir) { evaluate('with_file_store "data"') } }.to output("He wrote short stories.\n").to_stdout

      expect(provider_requests.first['tools'].map { |tool| tool['name'] })
        .to contain_exactly('list_files', 'read_file', 'search_files')
      expect(provider_requests.last['messages'].last['content'].to_s).to include('short stories growing up')
    end
  end

  it 'embeds an article on save and searches by its vector' do
    expect(evaluate('class Article')).to eq(['Returns'])

    expect(Article.first.embedding).to eq([0.1, 0.2])
    expect(searches).to eq([[[0.1, 0.2], :cosine]])
    expect(embedded).to eq([policy, 'How do I return a jacket?'])
  end

  it 'keeps the vector unchanged until the body changes' do
    evaluate('class Article')
    embedded.clear

    Article.first.update!(title: 'Refunds')
    expect(embedded).to be_empty

    Article.first.update!(body: 'Return any jacket within 60 days.')
    expect(embedded).to eq(['Return any jacket within 60 days.'])
  end

  it 'limits a search to three articles by default' do
    evaluate('class Article')
    %w[Sizing Care Shipping].each { |title| Article.create!(title:, body: title) }

    expect(Article.search('jacket').size).to eq(3)
  end

  it 'reranks candidates and maps the results back to records' do
    evaluate('class Article')
    Article.create!(title: 'Sizing', body: 'Our jackets run large.')
    stub_request(:post, 'https://api.cohere.com/v2/rerank').to_return do |request|
      provider_requests << JSON.parse(request.body)
      json_reply(results: [{ index: 1, relevance_score: 0.9 }, { index: 0, relevance_score: 0.2 }])
    end

    expect(evaluate('RubyLLM.rerank query').map(&:title)).to eq(%w[Sizing Returns])

    expect(provider_requests.last).to include('model' => doc_model('rerank_cohere'), 'top_n' => 2,
                                              'documents' => [policy, 'Our jackets run large.'])
  end

  it 'reads a scan into Markdown pages' do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'attention_is_all_you_need.pdf'), "%PDF-1.4\n")
      stub_request(:post, 'https://api.mistral.ai/v1/ocr')
        .to_return(json_reply(model: doc_model('default_ocr'), pages: [{ index: 0, markdown: '# Attention' }]))

      expect { Dir.chdir(dir) { evaluate('RubyLLM.ocr "attention') } }.to output("# Attention\n").to_stdout
    end
  end

  context 'with the agent that searches' do
    def source_id = Article.first.to_global_id.to_s

    def citation
      { type: 'search_result_location', source: source_id, title: 'Returns', cited_text: policy,
        search_result_index: 0, start_block_index: 0, end_block_index: 1 }
    end

    def replies
      [anthropic_json(model, tool_turn('search_docs', query: 'return a jacket')),
       json_reply(id: 'msg_doc', type: 'message', role: 'assistant', model:,
                  content: [{ type: 'text', text: answer, citations: [citation] }],
                  stop_reason: 'end_turn', usage: { input_tokens: 20, output_tokens: 10 })]
    end

    before do
      evaluate('class Article')
      queued = replies * 2
      stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return do |request|
        provider_requests << JSON.parse(request.body)
        queued.shift or raise 'Unexpected Anthropic request'
      end
    end

    it 'answers through the search tool' do
      expect { evaluate('class SearchDocs') }.to output("#{answer}\n").to_stdout

      expect(provider_requests.first['model']).to eq(model)
      expect(provider_requests.first['system'].to_s).to include('Search the help center before answering.')
      expect(provider_requests.first['tools'].first['name']).to eq('search_docs')
    end

    it 'sends the articles as citable search results' do
      silently { evaluate('class SearchDocs') }

      result = provider_requests.last['messages'].last['content'].first
      expect(result.to_s).to include('search_result', source_id, policy)
    end

    it 'tells the model when no article matches' do
      silently { evaluate('class SearchDocs') }
      allow(Article).to receive(:search).and_return([])

      expect(SearchDocs.new.execute(query: 'nothing')).to eq('No articles found')
    end

    it 'reads citations that point back at the record' do
      silently { evaluate('class SearchDocs') }
      allow(GlobalID::Locator).to receive(:locate).and_call_original

      citations = evaluate('response.citations.each', response: SupportAgent.new.ask('How do I return a jacket?'))

      expect(citations.first).to have_attributes(cited_text: policy, source_id:)
      expect(GlobalID::Locator).to have_received(:locate).with(source_id, only: Article)
    end
  end

  it 'pauses for approval, then continues in another request' do
    stub_const('ApplicationAgent', Class.new(RubyLLM::Agent) { chat_class Chat })
    stub_anthropic(tool_turn('issue_refund', order_id: 42), 'Refunded order 42.')

    expect(evaluate('class IssueRefund')).to be(true)
    expect(provider_requests.size).to eq(1)

    chat = Chat.last
    evaluate('chat.approve params', params: { id: chat.id, tool_call_id: chat.pending_approvals.first.tool_call_id })

    expect(Chat.last.messages.last.content).to eq('Refunded order 42.')
    expect(provider_requests.last['messages'][-1]['content'].to_s).to include('Refunded order 42')
  end

  it 'runs the two workflow steps in plain Ruby' do
    stub_const('JokeFlow', Class.new)
    stub_openai('A pirate joke.', 'It lands.')

    expect { evaluate('class JokeFlow') }.to output("It lands.\n").to_stdout

    expect(provider_requests.map { |request| request['model'] }).to eq([doc_model('openai_latest')] * 2)
    expect(provider_requests.first['input'].to_s).to include('Write your best joke about pirates.')
    expect(provider_requests.last['input'].to_s).to include('following joke: A pirate joke.')
  end

  it 'reports tokens and cost on chats and embeddings' do
    stub_anthropic(answer)

    expect(evaluate('embedding.cost.total')).to be_positive
    expect(RubyLLM.embed('How do I return a jacket?', model: doc_model('embedding_small')).cost.total).to be_positive
  end
end
