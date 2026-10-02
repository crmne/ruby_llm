# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Reasoning do
  describe '.format_reasoning_fields' do
    let(:model_without_budget) do
      instance_double(RubyLLM::Model, id: 'anthropic.claude-haiku-4-5', metadata: {},
                                      capabilities: ['reasoning'])
    end

    def reasoning_fields(thinking, model: model_without_budget)
      described_class.format_reasoning_fields(thinking, model)
    end

    it 'is nil when thinking is off' do
      expect(reasoning_fields(nil)).to be_nil
      expect(reasoning_fields(RubyLLM::Thinking::Config.new)).to be_nil
    end

    it 'is nil for an explicit none effort' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :none))).to be_nil
    end

    it 'maps effort to an advertised token budget' do
      model = instance_double(
        RubyLLM::Model,
        id: 'anthropic.claude-test',
        metadata: {
          converse: {
            additionalRequestFieldsSchema: JSON.generate(
              reasoningConfig: { budgetTokens: { enum: { low: 1024, high: 8192 }, minimum: 1024, maximum: 8192 } }
            )
          }
        }
      )

      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :high), model: model)).to eq(
        reasoning_config: { type: 'enabled', budget_tokens: 8192 }
      )
    end

    it 'sends a flat effort otherwise' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :low))).to eq(reasoning_effort: 'low')
    end

    it 'falls back to a token budget' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(budget: 2048))).to eq(
        reasoning_config: { type: 'enabled', budget_tokens: 2048 }
      )
    end
  end
end
