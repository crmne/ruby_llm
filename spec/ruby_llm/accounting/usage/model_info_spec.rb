# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Accounting::Usage::ModelInfo do
  let(:known) { RubyLLM.models.chat_models.first }

  {
    'Embedding' => ->(model) { RubyLLM::Embedding.new(vectors: [], model:) },
    'Rerank' => ->(model) { RubyLLM::Rerank.new(results: [], model:) },
    'Speech' => ->(model) { RubyLLM::Speech.new(data: '', model:) },
    'Transcription' => ->(model) { RubyLLM::Transcription.new(text: '', model:) }
  }.each do |name, build|
    context "with a #{name}" do
      it 'looks up its model in the registry' do
        expect(build.call(known.id).model_info&.id).to eq(known.id)
      end

      it 'answers nil for a model the registry does not know' do
        expect(build.call('no-such-model').model_info).to be_nil
      end

      it 'prefers the model the tracker assigned, even without a model id' do
        result = build.call(nil)
        result.model_info = known

        expect(result.model_info).to eq(known)
      end
    end
  end

  describe RubyLLM::Image do
    it 'looks up its model in the registry' do
      expect(described_class.new(model: known.id).model_info&.id).to eq(known.id)
    end

    it 'answers nil without a model, even when one was assigned' do
      image = described_class.new
      image.model_info = known

      expect(image.model_info).to be_nil
    end

    it 'answers nil for a model the registry does not know' do
      expect(described_class.new(model: 'no-such-model').model_info).to be_nil
    end
  end
end
