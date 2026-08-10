# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Embedding, :live do
  let(:test_text) { "Ruby is a programmer's best friend" }
  let(:test_texts) { %w[Ruby Python JavaScript] }
  let(:test_dimensions) { 768 }

  describe 'basic functionality' do
    each_model(EMBEDDING_MODELS) do |provider, model|
      it "#{provider}/#{model} can handle a single text" do
        embedding = RubyLLM.embed(test_text, model: model, provider: provider)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.first).to be_a(Float)
        expect(embedding.model).to eq(model)
        expect(embedding.tokens.input.to_i).to be >= 0
        expect(embedding).not_to respond_to(:input_tokens, :usage)
      end

      it "#{provider}/#{model} can handle a single text with custom dimensions" do
        skip 'Mistral does not support custom dimensions' if provider == :mistral
        skip 'Azure Cohere embeddings do not support custom dimensions' if provider == :azure
        skip 'Bedrock Titan only supports dimensions of 256, 512, or 1024' if provider == :bedrock

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
        expect(embeddings.tokens.input.to_i).to be >= 0
      end

      it "#{provider}/#{model} can handle multiple texts with custom dimensions" do
        skip 'Mistral does not support custom dimensions' if provider == :mistral
        skip 'Azure Cohere embeddings do not support custom dimensions' if provider == :azure
        skip 'Bedrock Titan only supports dimensions of 256, 512, or 1024' if provider == :bedrock

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

  describe 'Perplexity int8 embeddings' do
    it 'perplexity/pplx-embed-v1-0.6b decodes a single text into int8 vectors' do
      embedding = RubyLLM.embed(test_text, model: 'pplx-embed-v1-0.6b', provider: :perplexity)
      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(1024)
      expect(embedding.vectors.first).to be_an(Integer)
      expect(embedding.vectors).to all(be_between(-128, 127))
      expect(embedding.model).to eq('pplx-embed-v1-0.6b')
      expect(embedding.tokens.input.to_i).to be > 0
    end

    it 'perplexity/pplx-embed-v1-0.6b handles multiple texts with custom dimensions' do
      embeddings = RubyLLM.embed(test_texts, model: 'pplx-embed-v1-0.6b', provider: :perplexity, dimensions: 256)
      expect(embeddings.vectors.size).to eq(3)
      embeddings.vectors.each do |vector|
        expect(vector.length).to eq(256)
      end
    end
  end

  describe 'provider-reported cost' do
    it 'openrouter/openai/text-embedding-3-small returns the exact cost the provider reported' do
      embedding = RubyLLM.embed(test_text, model: 'openai/text-embedding-3-small', provider: :openrouter)

      expect(embedding.tokens.reported_cost).to be_positive
      expect(embedding.cost.total).to eq(embedding.tokens.reported_cost)
    end
  end
end
