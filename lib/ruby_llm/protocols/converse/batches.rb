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

        def validate_bedrock_batch_requests!(requests)
          unsupported = requests.any? do |request|
            payload = request.fetch(:payload)
            payload.key?(:toolConfig) || payload.key?('toolConfig') ||
              payload.key?(:outputConfig) || payload.key?('outputConfig')
          end
          return unless unsupported

          raise Error, 'bedrock batch requests do not support tools or structured output'
        end

        def parse_bedrock_model_output(body, model:)
          parse_completion_body({ 'modelId' => model }.merge(body), raw: body)
        end
      end
    end
  end
end
