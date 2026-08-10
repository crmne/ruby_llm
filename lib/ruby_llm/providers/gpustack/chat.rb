# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Chat methods of the GPUStack API integration
      module Chat
        module_function

        def format_content(content, attachments = [])
          GPUStack::Media.format_content(content, attachments)
        end

        def format_role(role)
          role.to_s
        end
      end
    end
  end
end
