# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Converse
      # Bedrock Model Invocation Jobs for Converse payloads.
      module Batches
        include Protocols::Bedrock::Batches

        private

        def bedrock_invocation_type
          'Converse'
        end

        def bedrock_batch_jsonl(requests)
          requests.map do |request|
            JSON.generate(recordId: request[:custom_id], modelInput: batch_payload(request))
          end.join("\n")
        end

        def validate_bedrock_batch_requests!(requests)
          unsupported = requests.any? do |request|
            payload = request.fetch(:payload)
            payload.key?(:toolConfig) || payload.key?('toolConfig') ||
              payload.key?(:outputConfig) || payload.key?('outputConfig')
          end
          return unless unsupported

          raise Error, 'bedrock batch requests do not support tools or structured output'
        end

        def parse_bedrock_outputs(outputs, **)
          outputs.flat_map { |body| parse_bedrock_output(body) }
        end

        def parse_bedrock_output(body)
          body.to_s.each_line.filter_map { |line| parse_bedrock_record(JSON.parse(line)) }
        end

        def parse_bedrock_record(line)
          record_id = line['recordId'] || line['record_id']
          index = batch_result_index(record_id)

          if line['modelOutput']
            body = line['modelOutput']
            [index, parse_completion_body(body, raw: body)]
          else
            [index, nil, batch_failure(record_id, line.dig('error', 'message') || line['errorMessage'])]
          end
        end
      end
    end
  end
end
