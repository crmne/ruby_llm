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
        SCHEMA_LITERAL_KEYS = %w[const default enum example examples].freeze
        NUMERIC_KEYS = %w[enum format minimum maximum].freeze
        TYPE_CONSTRAINTS = {
          'array' => %w[items minItems maxItems],
          'boolean' => [],
          'integer' => NUMERIC_KEYS,
          'number' => NUMERIC_KEYS,
          'object' => %w[properties required propertyOrdering minProperties maxProperties],
          'string' => %w[enum format minLength maxLength pattern]
        }.transform_values { |keys| (%w[description title] + keys).freeze }.freeze
        CONSTRAINED_KEYS = TYPE_CONSTRAINTS.values.flatten.uniq.freeze
        ENUM_VALUE_CLASSES = {
          'array' => [Array],
          'boolean' => [TrueClass, FalseClass],
          'integer' => [Integer],
          'null' => [NilClass],
          'number' => [Numeric],
          'object' => [Hash],
          'string' => [String]
        }.freeze
        private_constant :JSON_SCHEMA_ONLY_KEYS, :SCHEMA_LITERAL_KEYS, :NUMERIC_KEYS, :TYPE_CONSTRAINTS,
                         :CONSTRAINED_KEYS, :ENUM_VALUE_CLASSES

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

            converted[key] = response_schema_value(key.to_s, value)
          end
          render_type_union(schema)
        end

        def response_schema_value(key, value)
          return value if SCHEMA_LITERAL_KEYS.include?(key)
          if key == 'properties' && value.is_a?(Hash)
            return value.transform_values { |property| response_schema(property) }
          end

          response_schema(value)
        end

        def render_type_union(schema)
          key = schema.key?(:type) ? :type : 'type'
          return schema unless schema[key].is_a?(Array) && !schema[key].empty?

          types = enum_types(schema, schema[key])
          return schema.merge(key => types.first) if types.size == 1

          members = types - ['null']
          schema = schema.except('nullable').merge(nullable: true) if members.size < types.size
          return schema.merge(key => members.first) if members.size == 1

          render_union_members(schema, key, members)
        end

        def render_union_members(schema, type_key, members)
          if schema.key?(:anyOf) || schema.key?('anyOf')
            raise ArgumentError, 'Gemini Batch responseSchema cannot combine a type union and anyOf'
          end

          constraints, common = schema.except(type_key).partition { |key, _| CONSTRAINED_KEYS.include?(key.to_s) }
          branches = members.map { |member| union_branch(constraints, type_key, member) }
          common.to_h.merge(anyOf: branches)
        end

        def union_branch(constraints, type_key, member)
          keys = TYPE_CONSTRAINTS.fetch(member, [])
          branch = constraints.select { |key, _| keys.include?(key.to_s) }.to_h
          enum_key = branch.keys.find { |key| key.to_s == 'enum' }
          branch[enum_key] = enum_values(branch[enum_key], member) if enum_key
          branch.merge(type_key => member)
        end

        def enum_types(schema, types)
          enum = schema[:enum] || schema['enum']
          return types unless enum.is_a?(Array)

          allowed = types.select { |type| enum.any? { |value| enum_value?(value, type) } }
          allowed.empty? ? types : allowed
        end

        def enum_values(values, type)
          return values unless values.is_a?(Array)

          matching = values.select { |value| enum_value?(value, type) }
          matching.empty? ? values : matching
        end

        def enum_value?(value, type)
          classes = ENUM_VALUE_CLASSES[type]
          classes.nil? || classes.any? { |klass| value.is_a?(klass) }
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
