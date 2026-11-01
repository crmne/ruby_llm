# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # These Claude models bind a signed thinking block to the instructions,
      # tools, and messages it was written under, and refuse it once they
      # change. Dropping the block lets the model think that turn again.
      module BlockBinding # :nodoc:
        BETA = 'thinking-binding-controls-2026-08-01'
        MODELS = /claude-(?:(?:opus|sonnet|haiku)-5-5|fable-5-1)/
        DROP_STALE_BLOCKS = { prefix_mismatch_behavior: 'drop_block' }.freeze

        module_function

        def binds?(model_id)
          MODELS.match?(model_id.to_s)
        end

        # Returns +thinking+ with the binding added, or +nil+ when thinking
        # is set to anything but adaptive, which the binding would replace.
        def apply(thinking)
          return unless thinking.nil? || thinking[:type] == 'adaptive'

          { type: 'adaptive', **thinking.to_h, block_binding: DROP_STALE_BLOCKS }
        end
      end
    end
  end
end
