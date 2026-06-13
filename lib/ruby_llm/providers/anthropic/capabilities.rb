# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        module_function

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          true
        end

        # All current Claude models support citations except Haiku 3.
        def critical_capabilities_for(model_id)
          model_id.include?('claude-3-haiku') ? [] : ['citations']
        end
      end
    end
  end
end
