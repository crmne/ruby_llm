# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Embedding do
  include_context 'with configured RubyLLM'

  let(:test_text) { "Ruby is a programmer's best friend" }
  let(:test_texts) { %w[Ruby Python JavaScript] }
  let(:test_dimensions) { 768 }

  describe 'basic functionality' do
    EMBEDDING_MODELS.each do |config|
      provider = config[:provider]
      model = config[:model]
      it "#{provider}/#{model} can handle a single text" do
        embedding = RubyLLM.embed(test_text, model: model, provider: provider)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.first).to be_a(Float)
        expect(embedding.model).to eq(model)
        expect(embedding.input_tokens).to be >= 0
      end

      it "#{provider}/#{model} can handle a single text with custom dimensions" do
        skip 'Mistral does not support custom dimensions' if provider == :mistral

        embedding = RubyLLM.embed(test_text, model: model, provider: provider, dimensions: test_dimensions)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.length).to eq(test_dimensions)
      end

      it "#{provider}/#{model} can handle multiple texts" do
        embeddings = RubyLLM.embed(test_texts, model: model)
        expect(embeddings.vectors).to be_an(Array)
        expect(embeddings.vectors.size).to eq(3)
        expect(embeddings.vectors.first).to be_an(Array)
        expect(embeddings.model).to eq(model)
        expect(embeddings.input_tokens).to be >= 0
      end

      it "#{provider}/#{model} can handle multiple texts with custom dimensions" do
        skip 'Mistral does not support custom dimensions' if provider == :mistral

        embeddings = RubyLLM.embed(test_texts, model: model, provider: provider, dimensions: test_dimensions)
        expect(embeddings.vectors).to be_an(Array)
        embeddings.vectors.each do |vector|
          expect(vector.length).to eq(test_dimensions)
        end
      end

      it "#{provider}/#{model} handles single-string arrays consistently" do
        embeddings = RubyLLM.embed(['Ruby is great'], model: model, provider: provider)
        expect(embeddings.vectors).to be_an(Array)
        expect(embeddings.vectors.size).to eq(1)
        expect(embeddings.vectors.first).to be_an(Array)
        expect(embeddings.vectors.first.first).to be_a(Float)
      end
    end
  end
end
