# frozen_string_literal: true

module RubyLLM
  module Providers
    class Deepgram
      # Deepgram's dialect of Chat Completions on POST /v1/think. It takes
      # the full history on each request and rejects any field it does not
      # list, including the prompt cache fields.
      module Chat
        def completion_url
          @provider.think_url
        end

        # Think-Fast rejects the developer role.
        def render_role(role)
          role.to_s
        end

        def openai_prompt_caching?
          false
        end
      end
    end
  end
end
