# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Rerank, :live do
  include_context 'with configured RubyLLM'

  each_model(RERANK_MODELS) do |provider, model|
    it "#{provider}/#{model} orders documents by relevance" do
      rerank = RubyLLM.rerank(
        'What is the capital of the United States?',
        ['Carson City is the capital of Nevada.', 'Washington, D.C. is the capital of the United States.'],
        model: model,
        provider: provider,
        assume_model_exists: true
      )

      expect(rerank.results.first.document).to include('Washington')
      expect(rerank.results.first.score).to be > rerank.results.last.score
      expect(rerank.results.map(&:index)).to contain_exactly(0, 1)
    end
  end
end
