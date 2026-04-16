# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Embeddings methods for AWS Bedrock InvokeModel API.
      module Embeddings
        module_function

        def embedding_url(model:)
          "/model/#{model}/invoke"
        end

        def render_embedding_payload(text, model:, dimensions:) # rubocop:disable Lint/UnusedMethodArgument
          payload = { inputText: text.to_s }
          payload[:dimensions] = dimensions if dimensions
          payload[:normalize] = true
          payload
        end

        def parse_embedding_response(response, model:, text:) # rubocop:disable Lint/UnusedMethodArgument
          data = response.body
          vectors = data['embedding']
          input_tokens = data['inputTextTokenCount'] || 0

          Embedding.new(vectors:, model:, input_tokens:)
        end
      end
    end
  end
end
