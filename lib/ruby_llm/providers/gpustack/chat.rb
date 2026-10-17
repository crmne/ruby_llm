# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Chat methods of the GPUStack API integration
      module Chat
        module_function

        def render_content(content, attachments = [])
          GPUStack::Media.render_content(content, attachments)
        end

        def render_role(role)
          role.to_s
        end
      end
    end
  end
end
