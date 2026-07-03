# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Chat formatting for Perplexity provider
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        def format_content(content)
          Perplexity::Media.format_content(content)
        end
      end
    end
  end
end
