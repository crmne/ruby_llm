# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      class Gemini
        # Vertex AI Gemini batch prediction rows.
        module Batches
          include Protocols::VertexAI::BatchPrediction

          private

          def vertex_batch_request(request)
            payload = RubyLLM::Support::Utils.deep_stringify_keys(batch_payload(request))
            labels = payload.fetch('labels', {}).merge('ruby_llm_batch_id' => request[:custom_id])
            { request: payload.merge('labels' => labels) }
          end

          def parse_vertex_batch_result(line, fallback_index)
            index = vertex_batch_result_index(line, fallback_index)
            body = vertex_batch_response(line)

            if body
              [index, parse_completion_body(body, raw: body)]
            else
              [index, nil, batch_failure(index, vertex_batch_status_message(line))]
            end
          end
        end
      end
    end
  end
end
