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

        # rubocop:disable Lint/UnusedMethodArgument
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
          {
            model: model,
            input: text,
            dimensions: dimensions
          }.compact.merge(provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def parse_embedding_response(response, model:, text:)
          data = response.body
          input_tokens = data.dig('usage', 'prompt_tokens')
          vectors = data['data'].map { |d| d['embedding'] }
          vectors = vectors.first if vectors.length == 1 && !text.is_a?(Array)

          Embedding.new(vectors:, model:, input_tokens:, reported_cost: reported_cost(data['usage'] || {}))
        end

        def reported_cost(_usage)
          nil
        end
      end
    end
  end
end
