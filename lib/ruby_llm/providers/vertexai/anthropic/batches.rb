# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      class Anthropic
        # Vertex AI Claude batch prediction rows.
        module Batches
          include VertexAI::BatchPrediction

          private

          def vertex_batch_request(request)
            {
              custom_id: request[:custom_id],
              request: batch_params(request)
            }
          end

          def validate_batch_requests!(requests)
            if @config.vertexai_location.to_s == 'global'
              raise ConfigurationError, 'vertexai Anthropic batches require a regional vertexai_location'
            end

            return if requests.all? { |request| anthropic_batch_payload?(request.fetch(:params)) }

            raise Error, 'vertexai Anthropic batch requests require Anthropic message payloads'
          end

          def anthropic_batch_payload?(params)
            params.key?(:messages) || params.key?('messages')
          end

          def vertex_batch_model_path(model)
            @provider.model_path(model, publisher: 'anthropic')
          end

          def parse_vertex_batch_result(line, fallback_index)
            index = vertex_batch_result_index(line, fallback_index)
            body = line.dig('response', 'body') || line['response']

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
