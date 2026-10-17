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

        def parse_batch_result(line)
          body = line.dig('response', 'body')
          return super unless body.is_a?(Hash) && body['data'].is_a?(Array)
          unless valid_embedding_positions?(body['data'])
            return [batch_result_index(line['custom_id']), nil,
                    batch_failure(line['custom_id'], 'Invalid or duplicate embedding record positions')]
          end

          super
        end
      end
    end
  end
end
