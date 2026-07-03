# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Embeddings methods of the Anthropic API integration
      module Embeddings
        def embed(...)
          raise Error, "Anthropic doesn't support embeddings"
        end
      end
    end
  end
end
