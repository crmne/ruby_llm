# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # The Responses input-token counting endpoint.
      module TokenCounting
        COUNT_TOKENS_KEYS = %i[model input instructions tools tool_choice parallel_tool_calls reasoning text].freeze

        module_function

        def count_tokens_url
          "#{completion_url}/input_tokens"
        end

        def render_count_tokens_payload(messages, model:, **options)
          render_payload(messages, model: model, temperature: nil, **options).slice(*COUNT_TOKENS_KEYS)
        end

        def parse_count_tokens_response(response)
          response.body.fetch('input_tokens')
        end
      end
    end
  end
end
