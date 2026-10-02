# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Reasoning do
  describe '.format_reasoning_fields' do
    let(:model_without_budget) do
      instance_double(RubyLLM::Model, id: 'anthropic.claude-haiku-4-5', metadata: {}, reasoning_options: [],
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
        reasoning_options: [],
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

    it 'sends reasoning_config disabled when turning thinking off' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(enabled: false))).to eq(
        reasoning_config: { type: 'disabled' }
      )
    end

    it 'sends between_tools when turning thinking off on Sonnet 5.5' do
      model = instance_double(RubyLLM::Model, id: 'us.anthropic.claude-sonnet-5-5', metadata: {}, reasoning_options: [],
                                              capabilities: ['reasoning'])

      expect(reasoning_fields(RubyLLM::Thinking::Config.new(enabled: false), model: model)).to eq(
        thinking: { type: 'between_tools' }
      )
    end

    context 'with a Claude model that takes an effort but no budget' do
      let(:adaptive_model) { RubyLLM.models.find('us.anthropic.claude-sonnet-5', provider: :bedrock) }

      def config(**options)
        RubyLLM::Thinking::Config.new(**options)
      end

      it 'thinks adaptively with the effort in output_config' do
        expect(reasoning_fields(config(effort: :low), model: adaptive_model))
          .to eq(thinking: { type: 'adaptive' }, output_config: { effort: 'low' })
        expect(reasoning_fields(config(effort: :max),
                                model: RubyLLM.models.find('global.anthropic.claude-opus-4-8', provider: :bedrock)))
          .to eq(thinking: { type: 'adaptive' }, output_config: { effort: 'max' })
      end

      it 'turns adaptive thinking on when thinking is enabled without an effort' do
        expect(reasoning_fields(config(enabled: true), model: adaptive_model)).to eq(thinking: { type: 'adaptive' })
      end

      it 'is nil for an explicit none effort' do
        expect(reasoning_fields(config(effort: :none), model: adaptive_model)).to be_nil
      end

      it 'keeps an explicit budget and turning thinking off as they are' do
        expect(reasoning_fields(config(budget: 2048), model: adaptive_model))
          .to eq(reasoning_config: { type: 'enabled', budget_tokens: 2048 })
        expect(reasoning_fields(config(enabled: false), model: adaptive_model))
          .to eq(reasoning_config: { type: 'disabled' })
      end

      it 'reads the reasoning options of a Claude model reached through an inference profile ARN' do
        model = instance_double(RubyLLM::Model, max_output_tokens: nil, metadata: {}, reasoning_options: [],
                                                id: 'arn:aws:bedrock:us-west-2:123456789012:' \
                                                    'inference-profile/us.anthropic.claude-sonnet-5')

        expect(reasoning_fields(config(effort: :medium), model: model))
          .to eq(thinking: { type: 'adaptive' }, output_config: { effort: 'medium' })
      end

      it 'keeps budgets for Claude models that take one' do
        model = RubyLLM.models.find('us.anthropic.claude-haiku-4-5-20251001-v1:0', provider: :bedrock)

        expect(reasoning_fields(config(effort: :low), model: model))
          .to eq(reasoning_config: { type: 'enabled', budget_tokens: 1024 })
      end

      it 'thinks adaptively on Claude models whose schema names output_config.effort' do
        model = RubyLLM.models.find('us.anthropic.claude-fable-5-1', provider: :bedrock)

        expect(reasoning_fields(config(effort: :high), model: model))
          .to eq(thinking: { type: 'adaptive' }, output_config: { effort: 'high' })
      end
    end
  end
end
