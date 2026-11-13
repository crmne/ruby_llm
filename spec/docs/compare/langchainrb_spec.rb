# frozen_string_literal: true

require 'rails_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'RubyLLM and Langchain.rb guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/langchainrb.md' }
  let(:tmdb_requests) { [] }

  def model = doc_model('openai_latest')
  def answer = 'Inception is a 2010 film directed by Christopher Nolan.'

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('TMDB_API_KEY').and_return('tmdb-key')
    stub_request(:get, %r{\Ahttps://api\.themoviedb\.org/3/}).to_return do |request|
      tmdb_requests << request.uri
      details = request.uri.path.end_with?('/27205')
      { body: details ? '{"title":"Inception","runtime":148}' : '{"results":[{"id":27205}]}' }
    end
  end

  def movie_turns
    [tool_turn('search_movie', query: 'Inception'), tool_turn('get_movie_details', movie_id: 27_205), answer]
  end

  it 'answers through both movie tools' do
    stub_openai(*movie_turns)

    expect { evaluate('class MovieTool') }.to output("#{answer}\n").to_stdout

    expect(provider_requests.first['model']).to eq(model)
    expect(provider_requests.first['instructions'].to_s + provider_requests.first['input'].to_s)
      .to include('provide movie information')
    expect(provider_requests.first['tools'].map { |tool| tool['name'] })
      .to contain_exactly('search_movie', 'get_movie_details')
    expect(tmdb_requests.map(&:path)).to eq(['/3/search/movie', '/3/movie/27205'])
    expect(tmdb_requests.map(&:query_values)).to all(include('api_key' => 'tmdb-key'))
    expect(provider_requests.last['input'].to_s).to include('runtime', '148')
  end

  it 'streams the assistant with a block' do
    stub_openai(*movie_turns, *movie_turns)
    silently { evaluate('class MovieTool') }

    expect { evaluate('do |chunk|') }.to output(answer).to_stdout
  end

  it 'sends the same JSON Schema as the Langchain.rb hash and parses the reply' do
    character = { name: 'Kim Ji-hyun', age: 22, interests: [{ interest: 'Chemistry', levelOfInterest: 85 }] }
    stub_openai(JSON.generate(character))

    expect(evaluate('class Character')).to eq(JSON.parse(JSON.generate(character)))

    langchain_schema = doc_block('json_schema = {')[/json_schema = (\{.*?^\})$/m, 1]
    expected = JSON.parse(JSON.generate(TOPLEVEL_BINDING.dup.eval(langchain_schema)))
    sent = provider_requests.first.dig('text', 'format', 'schema')
    expect(sent.except('$schema', 'title')).to eq(expected)
  end

  context 'with the product catalog' do
    let(:searches) { [] }
    let(:embedded) { [] }

    # The page's Product uses the neighbor gem, which RubyLLM does not depend
    # on, so its two calls are stubbed and the rest is a real Active Record model.
    before do
      ActiveRecord::Base.connection.create_table(:products, temporary: true, force: true) do |t|
        t.string :name
        t.string :brand
        t.text :description
        t.boolean :in_stock
        t.json :embedding
      end
      allow(ApplicationRecord).to receive(:has_neighbors)
      allow(ApplicationRecord).to receive(:nearest_neighbors) do |_column, vector, distance:|
        searches << [vector, distance]
        Product.order(:id)
      end
      stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return do |request|
        embedded.concat(Array(JSON.parse(request.body)['input']))
        json_reply(model: doc_model('default_embedding'), data: [{ embedding: [0.1, 0.2] }],
                   usage: { prompt_tokens: 3, total_tokens: 3 })
      end
      evaluate('class Product')
      Product.create!(name: 'Trail runner', brand: 'Acme', description: 'Running shoe', in_stock: true)
    end

    after { ActiveRecord::Base.connection.drop_table(:products, if_exists: true) }

    it 'embeds a product when its text changes' do
      expect(embedded).to eq(['Trail runner: Running shoe'])
      expect(Product.first.embedding).to eq([0.1, 0.2])

      Product.first.update!(in_stock: false)
      expect(embedded.size).to eq(1)

      Product.first.update!(name: 'Trail runner 2')
      expect(embedded.last).to eq('Trail runner 2: Running shoe')
    end

    it 'answers from the catalog through the search tool' do
      stub_openai(tool_turn('search_products', query: 'running shoes in stock'), 'The Acme Trail runner is in stock.')

      expect { evaluate('class SearchProducts') }.to output("The Acme Trail runner is in stock.\n").to_stdout

      expect(searches).to eq([[[0.1, 0.2], :cosine]])
      expect(embedded.last).to eq('running shoes in stock')
      expect(provider_requests.last['input'].to_s).to include('Acme', 'Trail runner')
    end
  end

  it 'keeps the conversation in Chat records' do
    stub_openai(answer, 'Christopher Nolan directed it.')

    expect(evaluate('acts_as_chat', from: 'chat = Chat.create!').content).to eq('Christopher Nolan directed it.')

    expect(Chat.last.messages.count).to eq(4)
    expect(provider_requests.last['input'].to_s).to include('Inception', 'Who directed it?')
  end
end
