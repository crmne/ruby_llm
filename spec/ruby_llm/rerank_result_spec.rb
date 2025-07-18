# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::RerankResult do
  include_context 'with configured RubyLLM'


  describe 'class behavior' do
    let(:result_hash) do
      {
        index: 0,
        relevance_score: 0.85,
        document: 'Ruby is a dynamic, object-oriented programming language'
      }
    end

    it 'can be created from hash' do # rubocop:disable RSpec/MultipleExpectations
      result = described_class.from_hash(result_hash)

      expect(result.index).to eq(result_hash[:index])
      expect(result.relevance_score).to eq(result_hash[:relevance_score])
      expect(result.document).to eq(result_hash[:document])
    end

    it 'has accessible attributes' do # rubocop:disable RSpec/MultipleExpectations
      result = described_class.new(**result_hash)

      expect(result.index).to eq(result_hash[:index])
      expect(result.relevance_score).to eq(result_hash[:relevance_score])
      expect(result.document).to eq(result_hash[:document])
    end
  end
end
