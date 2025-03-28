# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'

RSpec.describe RubyLLM::Embedding do
  include_context 'with configured RubyLLM'

  let(:test_text) { "Ruby is a programmer's best friend" }
  let(:test_texts) { %w[Ruby Python JavaScript] }

  describe 'basic functionality' do
    [
      'text-embedding-004', # gemini
      'text-embedding-3-small', # openai
      'snowflake-arctic-embed:22m' # ollama
    ].each do |model|
      it "#{model} can handle a single text" do # rubocop:disable RSpec/MultipleExpectations
        embedding = RubyLLM.embed(test_text, model: model)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.first).to be_a(Float)
        expect(embedding.model).to eq(model)
        expect(embedding.input_tokens).to be >= 0
      end

      it "#{model} can handle multiple texts" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        embeddings = RubyLLM.embed(test_texts, model: model)
        expect(embeddings.vectors).to be_an(Array)
        expect(embeddings.vectors.size).to eq(3)
        expect(embeddings.vectors.first).to be_an(Array)
        expect(embeddings.model).to eq(model)
        expect(embeddings.input_tokens).to be >= 0
      end
    end
  end
end
