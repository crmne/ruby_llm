# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      class Anthropic
        # Bedrock Model Invocation Jobs whose records are InvokeModel bodies
        # in the Anthropic Messages format.
        module Batches
          include Protocols::Bedrock::Batches

          private

          def bedrock_invocation_type
            'InvokeModel'
          end

          def validate_bedrock_batch_requests!(_requests); end

          def bedrock_model_input(request)
            payload = batch_payload(request)
            render_invoke_body(payload, beta_headers(request[:headers].to_h, payload))
          end

          def parse_bedrock_model_output(body, model:)
            parse_completion_body(body.merge('model' => model), raw: body)
          end
        end
      end
    end
  end
end
