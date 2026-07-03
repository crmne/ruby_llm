# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      class ChatCompletions
        # Vertex AI MaaS batch prediction rows using OpenAI JSONL shape.
        module Batches
          include VertexAI::BatchPrediction

          private

          def vertex_batch_request(request)
            {
              custom_id: request[:custom_id],
              method: 'POST',
              url: '/v1/chat/completions',
              body: batch_params(request)
            }
          end

          def validate_batch_requests!(requests)
            return if requests.all? { |request| chat_completion_payload?(request.fetch(:params)) }

            raise Error, 'vertexai MaaS batch requests require chat completion payloads'
          end

          def chat_completion_payload?(params)
            params.key?(:messages) || params.key?('messages')
          end

          def vertex_batch_model_path(model)
            publisher, name = model.split('/', 2)
            raise Error, 'vertexai MaaS batch requests require publisher/model ids' unless publisher && name

            @provider.model_path(name, publisher:)
          end

          def parse_vertex_batch_result(line, fallback_index)
            index = vertex_batch_result_index(line, fallback_index)
            response = line['response']
            body = response.is_a?(Hash) ? response['body'] || response : response

            if body
              [index, parse_completion_body(body, raw: body)]
            else
              batch_failure(index, line.dig('status', 'message') || batch_error_message(line))
              [index, nil]
            end
          end
        end
      end
    end
  end
end
