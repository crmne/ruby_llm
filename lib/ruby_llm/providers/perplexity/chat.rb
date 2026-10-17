# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Chat formatting for Perplexity provider
      module Chat
        module_function

        def render_role(role)
          role.to_s
        end

        def supported_attachment?(attachment)
          Perplexity::Media.supported_attachment?(attachment)
        end

        def render_content(content, attachments = [])
          Perplexity::Media.render_content(content, attachments)
        end
      end
    end
  end
end
