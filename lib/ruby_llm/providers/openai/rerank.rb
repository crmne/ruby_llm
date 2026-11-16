# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # The Jina-style rerank endpoint that OpenAI-compatible servers such as
      # llama.cpp and vLLM serve at /v1/rerank. OpenAI's own API has none.
      class Rerank < Protocols::ChatCompletions # :nodoc:
        include Protocols::ChatCompletions::Rerank
      end
    end
  end
end
