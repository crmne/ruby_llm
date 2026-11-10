# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Amazon Nova multimodal embedding models over Bedrock InvokeModel.
      class NovaEmbeddings < InvokeModel
        DEFAULT_EMBEDDING_PURPOSE = 'GENERIC_INDEX'
        INPUT_TOKENS_HEADER = 'x-amzn-bedrock-input-token-count'
        MEDIA_TYPES = %i[image audio video].freeze

        def rejected_options(operation)
          operation == :embed ? %i[title] : super
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def embed(text, model:, dimensions:, task_type: nil, title: nil, with: nil, provider_options: {})
          attachment = embedding_attachment(text, embedding_attachments(text, with))
          track_usage(:embedding) do
            responses = [text].flatten.map do |value|
              payload = render_embedding_payload(value, dimensions:, task_type:, attachment:, provider_options:)
              signed_post(embedding_url(model:), payload).tap { |response| record_embedding_attempt(response) }
            end

            parse_single_embedding_responses(responses, model:, text:)
          end
        end

        private

        def embedding_attachment(text, attachments)
          attachment = single_embedding_attachment(attachments, 'Nova Multimodal Embeddings')
          return unless attachment

          unless text.to_s.empty?
            raise ArgumentError,
                  'Nova Multimodal Embeddings embeds text or an attachment, not both'
          end
          raise UnsupportedAttachmentError, attachment.mime_type unless MEDIA_TYPES.include?(attachment.type)

          attachment
        end

        def render_embedding_payload(text, dimensions:, task_type:, provider_options:, attachment: nil)
          params = { embeddingPurpose: task_type || DEFAULT_EMBEDDING_PURPOSE }
          params.merge!(attachment ? render_embedding_media(attachment) : render_embedding_text(text))
          params[:embeddingDimension] = dimensions if dimensions

          deep_merge_provider_options(
            {
              taskType: 'SINGLE_EMBEDDING',
              singleEmbeddingParams: params
            },
            provider_options
          )
        end

        def render_embedding_text(text)
          { text: { truncationMode: 'END', value: text.to_s } }
        end

        def render_embedding_media(attachment)
          source = { source: { bytes: attachment.encoded } }
          case attachment.type
          when :video
            format = attachment.extension || attachment.format
            { video: { format:, embeddingMode: 'AUDIO_VIDEO_COMBINED' }.merge(source) }
          else
            { attachment.type => { format: attachment.format }.merge(source) }
          end
        end

        def parse_embedding(body)
          body.dig('embeddings', 0, 'embedding')
        end

        # Nova leaves the count out of its body and sends it as a header.
        def embedding_attempt_tokens(responses)
          responses.map { |response| Tokens.new(input: response.headers[INPUT_TOKENS_HEADER]&.to_i) }
        end
      end
    end
  end
end
