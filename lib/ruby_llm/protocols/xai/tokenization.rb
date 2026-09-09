# frozen_string_literal: true

module RubyLLM
  module Protocols
    module XAI
      # xAI's plain-text tokenizer.
      module Tokenization
        def tokenization_url
          'tokenize-text'
        end

        def render_tokenization_payload(text, model:)
          { model:, text: }
        end

        def parse_tokenization_response(response, model:)
          ids = response.body.fetch('token_ids').map { |token| token.fetch('token_id') }
          RubyLLM::Tokenization.new(ids:, model:, raw: response.body)
        end
      end
    end
  end
end
