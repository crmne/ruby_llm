# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Embedding, :live do
  let(:test_text) { "Ruby is a programmer's best friend" }
  let(:test_texts) { %w[Ruby Python JavaScript] }
  let(:test_dimensions) { 768 }

  describe 'basic functionality' do
    each_model(EMBEDDING_MODELS) do |provider, model, model_info|
      it "#{provider}/#{model} can handle a single text" do
        embedding = RubyLLM.embed(test_text, model: model, provider: provider)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.first).to be_a(Float)
        expect(embedding.model).to eq(model)
        expect(embedding.tokens.input.to_i).to be >= 0
        expect(embedding).not_to respond_to(:input_tokens, :usage)
      end

      it "#{provider}/#{model} can handle a single text with custom dimensions" do
        dimensions = model_info.fetch(:dimensions, test_dimensions)
        skip "#{model} only returns its native dimensions" unless dimensions

        embedding = RubyLLM.embed(test_text, model: model, provider: provider, dimensions: dimensions)
        expect(embedding.vectors).to be_an(Array)
        expect(embedding.vectors.length).to eq(dimensions)
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
        dimensions = model_info.fetch(:dimensions, test_dimensions)
        skip "#{model} only returns its native dimensions" unless dimensions

        embeddings = RubyLLM.embed(test_texts, model: model, provider: provider, dimensions: dimensions)
        expect(embeddings.vectors).to be_an(Array)
        embeddings.vectors.each do |vector|
          expect(vector.length).to eq(dimensions)
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

  describe 'multimodal embeddings' do
    let(:image_path) { File.expand_path('../fixtures/ruby.png', __dir__) }

    it "gemini/#{model_for(:gemini, :multimodal_embedding)} embeds text with custom dimensions" do
      embedding = RubyLLM.embed(test_text, model: model_for(:gemini, :multimodal_embedding), provider: :gemini,
                                           dimensions: test_dimensions)
      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(test_dimensions)
      expect(embedding.vectors.first).to be_a(Float)
      expect(embedding.model).to eq(model_for(:gemini, :multimodal_embedding))
    end

    it "gemini/#{model_for(:gemini, :multimodal_embedding)} embeds an image alongside text" do
      embedding = RubyLLM.embed('The Ruby logo', model: model_for(:gemini, :multimodal_embedding), provider: :gemini,
                                                 with: image_path, dimensions: test_dimensions)
      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(test_dimensions)
      expect(embedding.vectors.first).to be_a(Float)
    end

    it 'raises UnsupportedAttachmentError on providers without multimodal embeddings' do
      expect do
        RubyLLM.embed(test_text, model: model_for(:openai, :embedding), provider: :openai, with: image_path)
      end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    end

    it 'rejects attachments alongside multiple texts' do
      expect do
        RubyLLM.embed(test_texts, model: model_for(:gemini, :multimodal_embedding), provider: :gemini, with: image_path)
      end.to raise_error(ArgumentError, /one text at a time/)
    end
  end

  describe 'Bedrock embedding dialects' do
    it "bedrock/#{model_for(:bedrock, :multimodal_embedding)} embeds a single text" do
      embedding = RubyLLM.embed(test_text, model: model_for(:bedrock, :multimodal_embedding), provider: :bedrock)

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.first).to be_a(Float)
      expect(embedding.model).to eq(model_for(:bedrock, :multimodal_embedding))
    end

    it "bedrock/#{model_for(:bedrock, :multimodal_embedding)} embeds multiple texts with custom dimensions" do
      embeddings = RubyLLM.embed(test_texts, model: model_for(:bedrock, :multimodal_embedding), provider: :bedrock,
                                             dimensions: 512)

      expect(embeddings.vectors.size).to eq(3)
      embeddings.vectors.each do |vector|
        expect(vector.length).to eq(512)
      end
    end

    # Nova multimodal embeddings are not served in us-west-2 yet.
    it "bedrock/#{model_for(:bedrock, :document_embedding)} embeds a single text" do
      context = RubyLLM.context { |config| config.bedrock_region = 'us-east-1' }
      embedding = context.embed(test_text, model: model_for(:bedrock, :document_embedding),
                                           provider: :bedrock, assume_model_exists: true, dimensions: 256)

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(256)
      expect(embedding.model).to eq(model_for(:bedrock, :document_embedding))
    end
  end

  describe 'Perplexity int8 embeddings' do
    it "perplexity/#{model_for(:perplexity, :passage_embedding)} decodes a single text into int8 vectors" do
      embedding = RubyLLM.embed(test_text, model: model_for(:perplexity, :passage_embedding), provider: :perplexity)
      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(1024)
      expect(embedding.vectors.first).to be_an(Integer)
      expect(embedding.vectors).to all(be_between(-128, 127))
      expect(embedding.model).to eq(model_for(:perplexity, :passage_embedding))
      expect(embedding.tokens.input.to_i).to be > 0
    end

    it "perplexity/#{model_for(:perplexity, :passage_embedding)} handles multiple texts with custom dimensions" do
      embeddings = RubyLLM.embed(test_texts, model: model_for(:perplexity, :passage_embedding), provider: :perplexity,
                                             dimensions: 256)
      expect(embeddings.vectors.size).to eq(3)
      embeddings.vectors.each do |vector|
        expect(vector.length).to eq(256)
      end
    end
  end

  describe 'provider-reported cost' do
    it "openrouter/#{model_for(:openrouter, :embedding)} returns the exact cost the provider reported" do
      embedding = RubyLLM.embed(test_text, model: model_for(:openrouter, :embedding), provider: :openrouter)

      expect(embedding.tokens.reported_cost).to be_positive
      expect(embedding.cost.total).to eq(embedding.tokens.reported_cost)
    end
  end
end
