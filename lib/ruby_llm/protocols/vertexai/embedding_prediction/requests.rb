# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      class EmbeddingPrediction
        # Input identity and model-specific batch embedding request formats.
        module Requests
          private

          def validate_embedding_request!(request)
            text = request.fetch(:text)
            values = text.is_a?(Array) ? text : [text]
            unless values.any? && values.all? { |value| value.is_a?(String) && !value.empty? }
              raise ArgumentError, 'Vertex AI embedding batches require nonempty text strings'
            end

            payload = request.fetch(:payload)
            validate_embedding_payload_keys!(payload)
            inputs = embedding_batch_inputs(payload)
            validate_gemini_embedding_options!(payload, inputs) if GEMINI_MODELS.include?(request.fetch(:model))
            return if inputs.size == values.size

            raise ArgumentError, 'Vertex AI embedding batch payload does not match the number of texts'
          end

          def validate_embedding_payload_keys!(payload)
            supported = if payload.key?(:instances)
                          %i[instances parameters]
                        elsif payload.key?(:requests)
                          [:requests]
                        else
                          %i[content outputDimensionality taskType title model]
                        end
            unknown = payload.keys - supported
            return if unknown.empty?

            raise ArgumentError, "Unsupported Vertex AI embedding batch options: #{unknown.join(', ')}"
          end

          def validate_gemini_embedding_options!(payload, inputs)
            parameters = payload.fetch(:parameters, {}).keys - [:outputDimensionality]
            supported = %i[content task_type taskType title outputDimensionality model]
            unsupported = inputs.flat_map(&:keys).uniq - supported
            return if parameters.empty? && unsupported.empty?

            raise ArgumentError, 'Vertex AI Gemini embedding batches do not support these options: ' \
                                 "#{(parameters + unsupported).join(', ')}"
          end

          def embedding_batch_inputs(payload)
            return payload.fetch(:instances) if payload.key?(:instances)
            return payload.fetch(:requests) if payload.key?(:requests)
            return [payload] if payload.key?(:content)

            raise ArgumentError, 'Vertex AI embedding batches require embedding request payloads'
          end

          def render_embedding_batch_rows(request)
            inputs = embedding_batch_inputs(request.fetch(:payload))
            array = request.fetch(:text).is_a?(Array)
            inputs.each_with_index.map do |input, index|
              key = "rllm-#{request.fetch(:custom_id)}-#{index}-#{inputs.size}-#{array ? 'a' : 's'}"
              if LEGACY_MODELS.include?(request.fetch(:model))
                input.merge(key:)
              else
                { key:, request: render_gemini_embedding_request(input, request.fetch(:payload)) }
              end
            end
          end

          def render_gemini_embedding_request(input, payload)
            content = input[:content]
            content = { parts: [{ text: content }] } if content.is_a?(String)
            config = {
              output_dimensionality: input[:outputDimensionality] || payload.dig(:parameters, :outputDimensionality),
              task_type: input[:task_type] || input[:taskType], title: input[:title]
            }.compact
            { content:, embed_content_config: config }
          end
        end
      end
    end
  end
end
