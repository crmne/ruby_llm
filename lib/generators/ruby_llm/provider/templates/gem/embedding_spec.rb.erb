# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Embedding, :live do
  include_context 'with configured RubyLLM'

  each_model(EMBEDDING_MODELS) do |provider, model, model_info|
    it "#{provider}/#{model} embeds one text" do
      embedding = RubyLLM.embed(
        "Ruby is a programmer's best friend",
        model: model,
        provider: provider,
        assume_model_exists: true
      )

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.first).to be_a(Numeric)
      expect(embedding.model).to eq(model)
      expect(embedding.tokens.input.to_i).to be >= 0
    end

    it "#{provider}/#{model} embeds several texts" do
      embeddings = RubyLLM.embed(
        %w[Ruby Python JavaScript],
        model: model,
        provider: provider,
        assume_model_exists: true
      )

      expect(embeddings.vectors.size).to eq(3)
      expect(embeddings.vectors).to all(be_an(Array))
    end

    next unless model_info[:dimensions]

    it "#{provider}/#{model} supports custom dimensions" do
      embedding = RubyLLM.embed(
        'Ruby',
        model: model,
        provider: provider,
        assume_model_exists: true,
        dimensions: model_info[:dimensions]
      )

      expect(embedding.vectors.length).to eq(model_info[:dimensions])
    end
  end
end
