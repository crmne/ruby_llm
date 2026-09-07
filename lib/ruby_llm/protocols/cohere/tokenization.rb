# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Cohere's plain-text tokenizer is served by the v1 API.
      module Tokenization
        def tokenization_url
          'v1/tokenize'
        end

        def render_tokenization_payload(text, model:)
          { model:, text: }
        end

        def parse_tokenization_response(response, model:)
          RubyLLM::Tokenization.new(ids: response.body.fetch('tokens'), model:, raw: response.body)
        end
      end
    end
  end
end
