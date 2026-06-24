# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TwelveLabs::Embeddings do
  include_context 'with configured RubyLLM'

  let(:model) { 'marengo3.0' }

  describe 'Marengo text embeddings' do
    it 'returns a single 512-dimensional float vector' do
      embedding = RubyLLM.embed('a cat', model: model, provider: :twelvelabs)

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(512)
      expect(embedding.vectors.first).to be_a(Float)
      expect(embedding.model).to eq(model)
    end

    it 'wraps a single-string array in one nested vector' do
      embedding = RubyLLM.embed(['a cat'], model: model, provider: :twelvelabs)

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.size).to eq(1)
      expect(embedding.vectors.first).to be_an(Array)
      expect(embedding.vectors.first.length).to eq(512)
    end

    it 'rejects multiple inputs, which the embed endpoint does not support' do
      expect do
        RubyLLM.embed(%w[a b], model: model, provider: :twelvelabs)
      end.to raise_error(RubyLLM::Error, /single text input/)
    end
  end
end
