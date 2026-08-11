# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # OpenAI-compatible file-backed Batch API for embeddings.
      module EmbeddingBatches
        include Protocols::OpenAI::Batches

        Response = Struct.new(:body)
        private_constant :Response

        private

        def batch_endpoint
          '/v1/embeddings'
        end

        def validate_batch_requests!(requests)
          return if requests.all? { |request| embedding_payload?(request.fetch(:payload)) }

          raise Error, "#{@provider.slug} embedding batch requests require embedding payloads"
        end

        def embedding_payload?(payload)
          payload.key?(:input) || payload.key?('input')
        end

        def parse_batch_completion_response(body)
          parse_embedding_response(Response.new(body), model: body['model'], text: nil)
        end
      end
    end
  end
end
