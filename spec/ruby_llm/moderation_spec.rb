# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Moderation do
  include_context 'with configured RubyLLM'

  let(:test_input) { 'This is a safe message' }

  describe '.moderate' do
    context 'with OpenAI provider' do
      it 'moderates content and returns a Moderation instance' do
        result = RubyLLM.moderate(test_input)

        expect(result).to be_a(described_class)
        expect(result.id).to be_present
        expect(result.model).to be_present
        expect(result.results).to all(be_a(RubyLLM::Moderation::Result))

        first = result.results.first
        expect(first.flagged?).to be_in([true, false])
        expect(first.categories).to all(be_a(String))
        expect(first.category_scores.values).to all(be_a(Numeric))
      end

      it 'provides convenience methods for checking results' do
        result = RubyLLM.moderate(test_input)

        expect(result.flagged?).to be_in([true, false])
        expect(result.flagged_categories).to be_an(Array)
        expect(result.category_scores).to be_a(Hash)
        expect(result.category_scores.keys).to all(be_a(String))
      end

      it 'can be called directly on the Moderation class' do
        result = described_class.moderate(test_input)

        expect(result).to be_a(described_class)
        expect(result.results).to be_present
      end

      it 'supports explicit model specification' do
        result = RubyLLM.moderate(test_input, provider: 'openai', assume_model_exists: true)

        expect(result).to be_a(described_class)
        expect(result.model).to be_present
      end
    end
  end
end
