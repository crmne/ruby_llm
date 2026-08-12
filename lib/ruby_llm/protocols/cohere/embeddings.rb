# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Embeddings methods for the Cohere v2 API integration
      module Embeddings
        DEFAULT_INPUT_TYPE = 'search_document'

        module_function

        def embedding_url(...)
          'v2/embed'
        end

        # rubocop:disable Lint/UnusedMethodArgument
        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          payload = {
            model: model,
            input_type: task_type || DEFAULT_INPUT_TYPE,
            embedding_types: ['float'],
            output_dimension: dimensions
          }.compact

          payload.merge!(embedding_inputs(text, with))
          Utils.deep_merge(payload, provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument

        def supports_embedding_media?
          true
        end

        def parse_embedding_response(response, model:, text:)
          data = response.body
          vectors = data.dig('embeddings', 'float')
          vectors = vectors.first if vectors&.length == 1 && !text.is_a?(Array)
          billed = data.dig('meta', 'billed_units') || {}

          Embedding.new(vectors:, model:, input_tokens: billed['input_tokens'])
        end

        # embed-v4 takes mixed text and images as `inputs`; text-only requests
        # keep using the simpler `texts` array every Embed model accepts.
        def embedding_inputs(text, attachments)
          return { texts: Utils.to_safe_array(text).map(&:to_s) } if attachments.empty?

          raise ArgumentError, 'embed one text at a time when embedding attachments' if text.is_a?(Array)

          { inputs: [{ content: Media.format_content(text, attachments) }] }
        end
      end
    end
  end
end
