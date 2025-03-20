module RubyLLM
  module Providers
    module Mistral
      # Handles function calling for Mistral models
      module Tools
        module_function

        def render_tool_choice(tool_choice)
          return 'none' if tool_choice == :none
          return 'auto' if tool_choice == :auto
          return 'any' if tool_choice == :any

          {
            type: 'function',
            function: { name: tool_choice }
          }
        end
      end
    end
  end
end
