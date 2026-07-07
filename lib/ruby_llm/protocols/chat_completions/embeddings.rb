# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Embeddings methods of the OpenAI API integration
      module Embeddings
        module_function

        def embedding_url(...)
          'embeddings'
        end

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          {
            model: model,
            input: text,
            dimensions: dimensions
          }.compact.merge(provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

        def parse_embedding_response(response, model:, text:)
          data = response.body
          input_tokens = data.dig('usage', 'prompt_tokens') || 0
          vectors = data['data'].map { |d| d['embedding'] }
          vectors = vectors.first if vectors.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:)
        end
      end
    end
  end
end
