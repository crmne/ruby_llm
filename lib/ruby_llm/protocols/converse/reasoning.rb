# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Reasoning request fields for Bedrock Converse, whose shape depends on
      # the model family.
      module Reasoning
        RANGED_EFFORTS = %w[low medium high].freeze
        MINIMUM_BUDGET_TOKENS = 1
        NOVA_DEFAULT_REASONING_EFFORT = 'low'

        module_function

        def format_reasoning_fields(thinking, model, max_output_tokens = nil)
          return nil unless thinking&.enabled?
          return format_nova_reasoning_fields(thinking, model) if nova_model?(model)
          return { reasoning_config: { type: 'disabled' } } if thinking.enabled == false

          effort = thinking.effort.to_s
          budget = reasoning_budget(thinking, effort, model, max_output_tokens)
          return { reasoning_config: { type: 'enabled', budget_tokens: budget } } if budget
          return nil if effort.empty? || effort == 'none'

          { reasoning_effort: effort }
        end

        def nova_model?(model)
          Chat.foundation_model_id(model&.id).start_with?('amazon.nova')
        end

        # Nova 2 takes reasoningConfig with an effort level instead of a token budget,
        # and rejects an enabled reasoningConfig that names no effort.
        def format_nova_reasoning_fields(thinking, model)
          if thinking.budget
            raise ArgumentError,
                  "#{model&.id} takes a reasoning effort, not a token budget of #{thinking.budget}. " \
                  'Pass with_thinking(effort:) instead.'
          end

          return { reasoningConfig: { type: 'disabled' } } if thinking.enabled == false

          effort = thinking.effort.to_s
          return nil if effort == 'none'

          effort = NOVA_DEFAULT_REASONING_EFFORT if effort.empty?
          { reasoningConfig: { type: 'enabled', maxReasoningEffort: effort } }
        end

        def reasoning_budget(thinking, effort, model, max_output_tokens)
          return thinking.budget if thinking.budget.is_a?(Integer)
          return nil if effort.empty? || effort == 'none'

          schema = reasoning_budget_schema(model)
          schema && effort_budget_tokens(effort, schema, max_output_tokens)
        end

        # Bedrock only publishes Converse metadata for some regional entries, so use the
        # schema from another entry for the same foundation model when needed.
        def reasoning_budget_schema(model)
          schema = budget_tokens_schema(model)
          return schema if schema
          return unless model

          foundation_id = Chat.foundation_model_id(model.id)
          RubyLLM.models.all.each do |candidate|
            next unless candidate.provider == 'bedrock' && candidate.id != model.id
            next unless Chat.foundation_model_id(candidate.id) == foundation_id

            return schema if (schema = budget_tokens_schema(candidate))
          end

          nil
        end

        def budget_tokens_schema(model)
          metadata = RubyLLM::Support::Utils.deep_symbolize_keys(model&.metadata || {})
          raw_schema = metadata.dig(:converse, :additionalRequestFieldsSchema)
          return unless raw_schema.is_a?(String)

          schema = JSON.parse(raw_schema, symbolize_names: true)
          budget = schema.is_a?(Hash) ? schema.dig(:reasoningConfig, :budgetTokens) : nil
          budget if budget.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end

        # Models that take a budget reject reasoning_effort, so effort has to become a budget.
        # Bedrock names the levels of an enumerated budget after the efforts they stand for;
        # otherwise the effort spans the range the schema allows.
        def effort_budget_tokens(effort, schema, max_output_tokens)
          budget = enumerated_budget(effort, schema) || ranged_budget(effort, schema)
          return nil unless budget

          minimum = schema[:minimum].is_a?(Integer) ? schema[:minimum] : MINIMUM_BUDGET_TOKENS
          return [budget, minimum].max unless max_output_tokens

          budget.clamp(minimum, [max_output_tokens - 1, minimum].max)
        end

        def enumerated_budget(effort, schema)
          levels = schema[:enum]
          level = levels.is_a?(Hash) ? levels[effort.to_sym] : nil
          level if level.is_a?(Integer)
        end

        def ranged_budget(effort, schema)
          minimum = schema[:minimum]
          maximum = schema[:maximum]
          return nil unless minimum.is_a?(Integer) && maximum.is_a?(Integer)

          case effort
          when 'low' then minimum
          when 'medium' then minimum + ((maximum - minimum) / 2)
          when 'high' then maximum
          else raise ArgumentError, unknown_effort_message(effort, schema)
          end
        end

        def unknown_effort_message(effort, schema)
          levels = schema[:enum].is_a?(Hash) ? schema[:enum].keys.map(&:to_s) : []
          levels |= RANGED_EFFORTS
          "Bedrock has no reasoning budget for effort #{effort.inspect}. " \
            "Use #{levels.join(', ')}, or pass an explicit budget."
        end
      end
    end
  end
end
