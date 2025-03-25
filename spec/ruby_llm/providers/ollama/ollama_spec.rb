# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.shared_context 'with configured local Ollama server' do
  before :all do
    RubyLLM.configure do |config|
      config.ollama_api_base_url = ENV.fetch('OLLAMA_API_BASE_URL', 'http://localhost:11434')

      # FIXME: need a sane internal API to do this, like RubyLLM.disable_all_providers()
      # FIXME: this will break other tests depending on run order
      config.openai_api_key = nil
      config.anthropic_api_key = nil
      config.gemini_api_key = nil
      config.deepseek_api_key = nil
    end
  end
end

RSpec.describe RubyLLM::Providers::Ollama do
  include_context 'with configured local Ollama server'

  describe '.models' do
    it 'fetches models from the server at runtime' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
      RubyLLM.models.refresh!

      # NOTE: to ensure relevant models are pulled into your local server, do
      #   bundle exec rake ollama:install_models_for_specs

      expect(RubyLLM.models).to include(
        an_object_having_attributes(provider: 'ollama', id: 'smollm:135m')
      )
      expect(RubyLLM.models).to include(
        an_object_having_attributes(provider: 'ollama', id: 'snowflake-arctic-embed:22m')
      )
    end
  end

  describe '.chat' do
    let(:chat) { RubyLLM.chat(model: 'smollm:135m', provider: 'ollama') }

    it 'ask works' do
      response = chat.ask('Count from 1 to 3')
      expect(response.content).to be_present
    end
  end

  describe 'streaming' do
    let(:chat) { RubyLLM.chat(model: 'smollm:135m', provider: 'ollama') }

    it 'ask with streaming works' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
      chunks = []

      chat.ask('Count from 1 to 3') do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::Chunk)
    end
  end

  describe 'embeddings' do
    let(:test_text) { "Ruby is a programmer's best friend" }
    let(:test_texts) { %w[Ruby Python JavaScript] }
    let(:model) { 'snowflake-arctic-embed:22m' }

    it 'can handle a single text' do # rubocop:disable RSpec/MultipleExpectations
      # FIXME: need a provider: param just like in chat()
      # embedding = RubyLLM.embed(test_text, model: model, provider: 'ollama')

      embedding = RubyLLM.embed(test_text, model: model)
      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.first).to be_a(Float)
      expect(embedding.model).to eq(model)
      expect(embedding.input_tokens).to be >= 0
    end

    it 'can handle multiple texts' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # FIXME: need a provider: param just like in chat()
      # embeddings = RubyLLM.embed(test_texts, model: model, provider: 'ollama')

      embeddings = RubyLLM.embed(test_texts, model: model)
      expect(embeddings.vectors).to be_an(Array)
      expect(embeddings.vectors.size).to eq(3)
      expect(embeddings.vectors.first).to be_an(Array)
      expect(embeddings.model).to eq(model)
      expect(embeddings.input_tokens).to be >= 0
    end
  end
end
