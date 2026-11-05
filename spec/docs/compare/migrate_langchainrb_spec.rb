# frozen_string_literal: true

require 'spec_helper'
require_relative 'doc_example_helpers'

RSpec.describe 'Migrating from langchainrb guide', type: :task do
  include DocExampleHelpers

  include_context 'with configured RubyLLM'

  let(:doc_page) { '_compare/migrate-langchainrb.md' }

  it 'chats with instructions' do
    stub_openai('Sunny.')

    expect(evaluate('response.content')).to eq('Sunny.')
    expect(provider_requests.first['instructions'] || provider_requests.first['input'].first['content'].to_s)
      .to include('You are a helpful assistant.')
  end

  it 'switches providers by model name' do
    expect(evaluate('chat = RubyLLM.chat model: "claude').model.provider).to eq('anthropic')
  end

  it 'embeds text' do
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(body: JSON.generate(data: [{ embedding: [0.1, 0.2] }], model: 'text-embedding-3-small',
                                     usage: { prompt_tokens: 3, total_tokens: 3 }),
                 headers: { 'Content-Type' => 'application/json' })

    expect(evaluate('RubyLLM.embed("Hello, world!").vector')).to eq([0.1, 0.2])
  end

  it 'answers from the recipe collection through a search tool' do
    recipes = Struct.new(:content)
    neighbors = [recipes.new('Sear for 3-4 minutes per side.')]
    stub_const('Document', Class.new do
      define_singleton_method(:nearest_neighbors) { |*_args, **_options| neighbors }
    end)
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(body: JSON.generate(data: [{ embedding: [0.1, 0.2] }], model: 'text-embedding-3-small',
                                     usage: { prompt_tokens: 3, total_tokens: 3 }),
                 headers: { 'Content-Type' => 'application/json' })
    stub_openai(tool_turn('search_recipes', query: 'sear chicken'), 'Sear it for 3-4 minutes per side.')

    answer = evaluate('class SearchRecipes')

    expect(answer.content).to eq('Sear it for 3-4 minutes per side.')
    result = provider_requests.last['input'].find { |item| item['type'] == 'function_call_output' }
    expect(result['output']).to include('Sear for 3-4 minutes per side.')
  end

  context 'with the movie assistant' do
    before do
      stub_const('Tmdb', Module.new do
        def self.search(query) = [{ id: 27_205, title: query }]
        def self.movie(id) = { id:, title: 'Inception', year: 2010 }
      end)
    end

    it 'runs both tools from an agent' do
      stub_openai(tool_turn('search_movie', query: 'Inception'), tool_turn('movie_details', movie_id: 27_205),
                  'Inception is a 2010 film.')

      answer = evaluate('class SearchMovie')

      expect(answer.content).to eq('Inception is a 2010 film.')
      details = provider_requests.first['tools'].find { |tool| tool['name'] == 'movie_details' }
      expect(details['parameters']['properties']['movie_id']['type']).to eq('integer')
      outputs = provider_requests.last['input'].select { |item| item['type'] == 'function_call_output' }
      expect(outputs.last['output']).to include('2010')
    end

    it 'streams the answer from the agent' do
      stub_openai('Inception is a 2010 film.', 'Inception, 2010.')
      evaluate('class SearchMovie')

      expect { evaluate('do |chunk|') }.to output('Inception, 2010.').to_stdout
    end
  end
end
