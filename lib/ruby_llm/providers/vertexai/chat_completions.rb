# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      # MaaS models (publisher-prefixed ids like meta/llama-3.3-70b-instruct-maas)
      # speak Chat Completions through Vertex AI's OpenAI-compatible endpoint.
      class ChatCompletions < Protocols::ChatCompletions
        def completion_url
          "#{@provider.location_path}/endpoints/openapi/chat/completions"
        end
      end
    end
  end
end
