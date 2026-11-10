# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Amazon Titan multimodal embedding models over Bedrock InvokeModel.
      class TitanMultimodalEmbeddings < InvokeModel
        # rubocop:disable-next Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          image = embedding_image(embedding_attachments(text, with))
          track_usage(:embedding) do
            responses = [text].flatten.map do |value|
              payload = render_embedding_payload(value, dimensions:, image:, provider_options:)
              signed_post(embedding_url(model:), payload).tap { |response| record_embedding_attempt(response) }
            end

            parse_single_embedding_responses(responses, model:, text:)
          end
        end

        private

        def embedding_image(attachments)
          attachment = single_embedding_attachment(attachments, 'Titan Multimodal Embeddings')
          raise UnsupportedAttachmentError, attachment.mime_type if attachment && !attachment.image?

          attachment
        end

        def render_embedding_payload(text, dimensions:, provider_options:, image: nil, **)
          payload = {}
          payload[:inputText] = text.to_s unless text.nil? || text.to_s.empty?
          payload[:inputImage] = image.encoded if image
          payload[:embeddingConfig] = { outputEmbeddingLength: dimensions } if dimensions

          deep_merge_provider_options(payload, provider_options)
        end
      end
    end
  end
end
