# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Gemini Batch API with inlined generateContent requests.
      module Batches
        include RubyLLM::Batch::Helpers

        # The wire enum is BATCH_STATE_*; the SDKs print JOB_STATE_*. Match the
        # suffix so either spelling works.
        TERMINAL = %w[SUCCEEDED FAILED CANCELLED EXPIRED].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'gemini')
          response = @connection.post("models/#{model}:batchGenerateContent", {
                                        batch: {
                                          displayName: "ruby_llm_#{SecureRandom.hex(8)}",
                                          inputConfig: {
                                            requests: {
                                              requests: requests.map { |request| gemini_batch_request(request, model) }
                                            }
                                          }
                                        }
                                      }, idempotent: false)

          parse_batch_response(response.body)
        end

        def find_batch(id)
          parse_batch_response @connection.get(batch_name(id)).body
        end

        def cancel_batch(id)
          @connection.post("#{batch_name(id)}:cancel", {})
          find_batch(id)
        end

        # Inline answers are correlated by the key we sent (the submission index);
        # Gemini also returns them in order, so we fall back to position.
        def batch_results(id)
          body = @connection.get(batch_name(id)).body
          inlined = body.dig('response', 'inlinedResponses', 'inlinedResponses') ||
                    body.dig('output', 'inlinedResponses', 'inlinedResponses') || []
          inlined.each_with_index.map { |response, index| parse_inline_response(response, index) }
        end

        private

        def gemini_batch_request(request, model)
          {
            request: batch_schema_payload(batch_payload(request)).merge(model: "models/#{model}"),
            metadata: {
              custom_id: request[:custom_id]
            }
          }
        end

        # batchGenerateContent ignores responseJsonSchema and returns JSON of
        # its own shape, while the legacy responseSchema field is honored, so
        # batches carry the schema in Gemini's Schema dialect.
        def batch_schema_payload(payload)
          config = payload[:generationConfig]
          return payload unless config.is_a?(Hash) && config.key?(:responseJsonSchema)

          schema = response_schema(config[:responseJsonSchema])
          payload.merge(generationConfig: config.except(:responseJsonSchema).merge(responseSchema: schema))
        end

        JSON_SCHEMA_ONLY_KEYS = %w[$schema $id additionalProperties strict].freeze
        private_constant :JSON_SCHEMA_ONLY_KEYS

        def response_schema(node)
          case node
          when Hash then response_schema_hash(node)
          when Array then node.map { |value| response_schema(value) }
          else node
          end
        end

        def response_schema_hash(node)
          schema = node.each_with_object({}) do |(key, value), converted|
            next if JSON_SCHEMA_ONLY_KEYS.include?(key.to_s)

            converted[key] = if key.to_s == 'properties' && value.is_a?(Hash)
                               value.transform_values { |property| response_schema(property) }
                             else
                               response_schema(value)
                             end
          end
          nullable_type(schema)
        end

        def nullable_type(schema)
          key = schema.key?(:type) ? :type : 'type'
          types = Array(schema[key])
          return schema unless types.length > 1 && types.include?('null')

          schema.merge(key => (types - ['null']).first, nullable: true)
        end

        def batch_name(id)
          id.to_s.start_with?('batches/') ? id : "batches/#{id}"
        end

        # A batch starts as an Operation wrapping the batch in `metadata`; polling
        # returns the batch directly. Read either shape.
        def parse_batch_response(data)
          batch = data['metadata'] || data
          state = batch['state']
          request_counts = batch['batchStats']

          {
            id: data['name'] || batch['name'],
            raw_status: state,
            completed: TERMINAL.any? { |terminal| state&.end_with?(terminal) },
            request_counts:,
            request_count: request_counts&.fetch('requestCount', nil)&.to_i
          }
        end

        def parse_batch_status(raw_status, completed:)
          return :pending unless completed
          return :succeeded if raw_status&.end_with?('SUCCEEDED')
          return :cancelled if raw_status&.end_with?('CANCELLED')

          :failed
        end

        def parse_inline_response(inline, index)
          key = inline.dig('metadata', 'custom_id') || inline.dig('metadata', 'key')
          index = batch_result_index(key) if key

          if inline['response']
            body = inline['response']
            [index, parse_completion_body(body, raw: body)]
          else
            [index, nil, batch_failure(key || index, inline.dig('error', 'message'))]
          end
        end
      end
    end
  end
end
