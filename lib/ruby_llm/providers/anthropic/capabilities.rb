# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        module_function

        # All current Claude models support citations except Haiku 3, and all
        # support steering tool choice and parallel tool calls.
        def critical_capabilities_for(model_id)
          capabilities = model_id.include?('claude-3-haiku') ? [] : ['citations']
          capabilities + %w[tool_choice parallel_tool_calls]
        end
      end
    end
  end
end
