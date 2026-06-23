# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI < Provider
      class Gemini
        # Vertex AI Gemini batch prediction rows.
        module Batches
          include VertexAI::BatchPrediction

          private

          def vertex_batch_request(request)
            params = RubyLLM::Utils.deep_stringify_keys(batch_params(request))
            labels = params.fetch('labels', {}).merge('ruby_llm_batch_id' => request[:custom_id])
            { request: params.merge('labels' => labels) }
          end

          def parse_vertex_batch_result(line, fallback_index)
            index = vertex_batch_result_index(line, fallback_index)

            if line['response']
              body = line['response']
              [index, parse_completion_body(body, raw: body)]
            else
              batch_failure(index, line.dig('status', 'message'))
              [index, nil]
            end
          end
        end
      end
    end
  end
end
