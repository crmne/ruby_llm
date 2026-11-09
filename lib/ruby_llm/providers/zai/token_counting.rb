# frozen_string_literal: true

module RubyLLM
  module Providers
    class ZAI
      # Counts a request through Z.ai's tokenizer, which takes the chat
      # messages and tools and leaves response format and thinking out.
      module TokenCounting
        COUNT_TOKENS_KEYS = %i[model messages tools].freeze

        def count_tokens_url
          'tokenizer'
        end

        def render_count_tokens_payload(messages, model:, **)
          render_payload(messages, model: model, temperature: nil, **).slice(*COUNT_TOKENS_KEYS)
        end

        def parse_count_tokens_response(response)
          response.body.fetch('usage').fetch('total_tokens')
        end
      end
    end
  end
end
