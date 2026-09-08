# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure do
  describe '.capabilities' do
    it 'registers a model capability augmenter' do
      expect(described_class.capabilities).to respond_to(:augment)
    end

    it 'includes verified tool controls for Grok 4.1 Fast non-reasoning' do
      model = merge_capabilities([], 'grok-4-1-fast-non-reasoning')

      expect(model.capabilities).to contain_exactly('tool_choice', 'parallel_tool_calls')
    end

    it 'does not infer tool controls for another model' do
      model = merge_capabilities([], 'Cohere-embed-v3-english')

      expect(model.capabilities).to eq([])
    end

    it 'preserves existing capabilities without duplicates or mutation' do
      original = %w[function_calling tool_choice].freeze
      model = merge_capabilities(original, 'grok-4-1-fast-non-reasoning')

      expect(model.capabilities).to contain_exactly('function_calling', 'tool_choice', 'parallel_tool_calls')
      expect(original).to eq(%w[function_calling tool_choice])
    end
  end

  def merge_capabilities(capabilities, model_id)
    attributes = RubyLLM.models.find(model_id, provider: :azure).to_h.merge(capabilities: capabilities)
    model = RubyLLM::Model.new(attributes)

    RubyLLM::Models.merge_models([model], []).first
  end
end
