# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Amazon Titan text embedding models over Bedrock InvokeModel.
      class TitanTextEmbeddings < InvokeModel
        # rubocop:disable Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          ensure_no_embedding_media!(with)
          track_usage(:embedding) do
            responses = [text].flatten.map do |value|
              payload = render_embedding_payload(value, model:, dimensions:, provider_options:)
              signed_post(embedding_url(model:), payload).tap { |response| record_embedding_attempt(response) }
            end

            parse_single_embedding_responses(responses, model:, text:)
          end
        end
        # rubocop:enable Lint/UnusedMethodArgument

        private

        # The G1 and V1 models take inputText alone; Bedrock rejects the V2
        # tuning keys as extraneous.
        def render_embedding_payload(text, model:, dimensions:, provider_options:)
          payload = { inputText: text.to_s }

          if titan_v2?(model)
            payload[:dimensions] = dimensions if dimensions
            payload[:normalize] = true
          elsif dimensions
            raise Error, "#{model} does not support custom dimensions"
          end

          deep_merge_provider_options(payload, provider_options)
        end

        def titan_v2?(model)
          model.to_s.include?('titan-embed-text-v2')
        end
      end
    end
  end
end
