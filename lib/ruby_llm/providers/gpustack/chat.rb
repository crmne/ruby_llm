# frozen_string_literal: true

module RubyLLM
  module Providers
    module GPUStack
      # Chat methods of the GPUStack API integration
      module Chat
        module_function

        def format_role(role)
          # GPUStack doesn't use the new OpenAI convention for system prompts
          role.to_s
        end
      end
    end
  end
end
