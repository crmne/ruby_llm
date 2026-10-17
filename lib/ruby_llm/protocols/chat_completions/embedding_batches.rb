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

        def batch_request_line(request)
          line = super
          line[:custom_id] = "#{line[:custom_id]}:array" if request[:text].is_a?(Array)
          line
        end

        def parse_batch_completion_response(body, shape: nil)
          parse_embedding_response(Response.new(body), model: body['model'], text: shape == 'array' ? [] : nil)
        end

        def parse_batch_result(line)
          custom_id, shape = line['custom_id'].split(':', 2)
          line = line.merge('custom_id' => custom_id)
          body = line.dig('response', 'body')
          return super unless body.is_a?(Hash) && body['data'].is_a?(Array)

          index = batch_result_index(custom_id)
          unless valid_embedding_positions?(body['data'])
            return [index, nil, batch_failure(custom_id, 'Invalid or duplicate embedding record positions')]
          end
          return super unless batch_response_succeeded?(line['response'])

          [index, parse_batch_completion_response(body, shape:)]
        end
      end
    end
  end
end
