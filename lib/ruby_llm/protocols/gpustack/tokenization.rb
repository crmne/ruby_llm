# frozen_string_literal: true

module RubyLLM
  module Protocols
    module GPUStack
      # vLLM's text tokenizer through GPUStack's model proxy.
      module Tokenization
        COUNT_TOKENS_KEYS = %i[model messages tools].freeze

        def tokenization_url
          "#{@provider.backend_api_base}/tokenize"
        end

        def render_tokenization_payload(text, model:)
          { model: model, prompt: text }
        end

        def parse_tokenization_response(response, model:)
          RubyLLM::Tokenization.new(ids: response.body.fetch('tokens'), model: model, raw: response.body)
        end

        def count_tokens_url
          tokenization_url
        end

        def render_count_tokens_payload(messages, **)
          render_payload(messages, temperature: nil, **).slice(*COUNT_TOKENS_KEYS)
        end

        def parse_count_tokens_response(response)
          response.body.fetch('count')
        end
      end
    end
  end
end
