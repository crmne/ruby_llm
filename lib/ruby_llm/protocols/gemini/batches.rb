# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Gemini Batch API with inlined generateContent requests.
      module Batches
        include RubyLLM::Batch::Helpers
        include Gemini::EmbeddingBatches

        # The wire enum is BATCH_STATE_*; the SDKs print JOB_STATE_*. Match the
        # suffix so either spelling works.
        TERMINAL = %w[SUCCEEDED FAILED CANCELLED EXPIRED].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'gemini')
          action = embedding_batch?(requests) ? 'asyncBatchEmbedContent' : 'batchGenerateContent'
          response = @connection.post("models/#{model}:#{action}", {
                                        batch: {
                                          displayName: "ruby_llm_#{SecureRandom.hex(8)}",
                                          inputConfig: {
                                            requests: {
                                              requests: requests.flat_map do |request|
                                                if embedding_batch_payload?(request.fetch(:payload))
                                                  embedding_batch_requests(request, model)
                                                else
                                                  [gemini_batch_request(request, model)]
                                                end
                                              end
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
          inlined = inline_batch_responses(body)
          return parse_embedding_batch_results(inlined) if embedding_batch_response?(body)

          inlined.each_with_index.map { |response, index| parse_inline_response(response, index) }
        end

        private

        def inline_batch_responses(body)
          body.dig('response', 'inlinedEmbedContentResponses', 'inlinedResponses') ||
            body.dig('output', 'inlinedEmbedContentResponses', 'inlinedResponses') ||
            body.dig('response', 'inlinedResponses', 'inlinedResponses') ||
            body.dig('output', 'inlinedResponses', 'inlinedResponses') ||
            body.dig('metadata', 'output', 'inlinedResponses', 'inlinedResponses') || []
        end

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
          type_union(schema)
        end

        TYPE_KEYWORDS = {
          'string' => %w[format maxLength minLength pattern],
          'number' => %w[format maximum minimum exclusiveMaximum exclusiveMinimum multipleOf],
          'integer' => %w[format maximum minimum exclusiveMaximum exclusiveMinimum multipleOf],
          'object' => %w[properties required maxProperties minProperties propertyOrdering],
          'array' => %w[items maxItems minItems prefixItems uniqueItems]
        }.freeze
        TYPED_KEYWORDS = TYPE_KEYWORDS.values.flatten.uniq.freeze
        ENUM_VALUE_TYPES = {
          'string' => ->(value) { value.is_a?(String) },
          'number' => ->(value) { value.is_a?(Numeric) },
          'integer' => ->(value) { value.is_a?(Integer) },
          'boolean' => ->(value) { [true, false].include?(value) },
          'object' => ->(value) { value.is_a?(Hash) },
          'array' => ->(value) { value.is_a?(Array) },
          'null' => lambda(&:nil?)
        }.freeze
        private_constant :TYPE_KEYWORDS, :TYPED_KEYWORDS, :ENUM_VALUE_TYPES

        # Gemini's Schema takes one type, so a JSON Schema type array becomes
        # nullable plus anyOf, each member keeping the keywords and enum
        # values of its type.
        def type_union(schema)
          key = schema.key?(:type) ? :type : 'type'
          return schema unless schema[key].is_a?(Array)

          types = schema[key].map(&:to_s).uniq
          return schema.merge(key => types.first) if types.one?

          types = enum_types(schema, types)
          others = types - ['null']
          return schema.merge(key => 'null') if others.empty?

          union = type_union_members(schema.except(key), others)
          types.include?('null') ? union.merge(nullable: true) : union
        end

        def type_union_members(schema, types)
          return union_member(schema, types.first) if types.one?

          { anyOf: types.map { |type| union_member(schema, type) } }
        end

        def union_member(schema, type)
          own = TYPE_KEYWORDS.fetch(type, [])
          member = schema.reject { |name, _| TYPED_KEYWORDS.include?(name.to_s) && !own.include?(name.to_s) }
          values = member[enum_key(member)]
          member = member.merge(enum_key(member) => values.select(&enum_value_of(type))) if values.is_a?(Array)
          { type: }.merge(member)
        end

        def enum_types(schema, types)
          values = schema[enum_key(schema)]
          return types unless values.is_a?(Array)

          matching = types.select { |type| values.any?(&enum_value_of(type)) }
          matching.empty? ? types : matching
        end

        def enum_key(schema)
          schema.key?(:enum) ? :enum : 'enum'
        end

        def enum_value_of(type)
          ENUM_VALUE_TYPES.fetch(type) { ->(_) { true } }
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
            request_count: (request_counts&.fetch('requestCount', nil)&.to_i unless embedding_batch_response?(data))
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
