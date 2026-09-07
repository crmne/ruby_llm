# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Text and multimodal embedding requests for OpenRouter.
      module Embeddings
        EMBEDDING_MEDIA_TYPES = { audio: :input_audio, video: :input_video, pdf: :input_file }.freeze

        module_function

        def supports_embedding_media?
          true
        end

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          input = if with.any?
                    raise ArgumentError, 'embed one text at a time when embedding attachments' if text.is_a?(Array)

                    [{ content: format_embedding_content(text, with) }]
                  else
                    text
                  end

          payload = super(input, model:, dimensions:, task_type:, title:, provider_options: {})
          payload[:input_type] = task_type if task_type
          payload.merge(provider_options)
        end

        def format_embedding_content(text, attachments)
          Protocols::ChatCompletions::Media.format_parts(text, attachments) do |attachment|
            format_embedding_attachment(attachment)
          end
        end

        def format_embedding_attachment(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type if attachment.provider_file?

          if (type = EMBEDDING_MEDIA_TYPES[attachment.type])
            { type: type.to_s, type => { data: attachment.for_llm, format: attachment.format } }
          else
            Protocols::ChatCompletions::Media.format_attachment(
              attachment, document_attachments: :none, image_attachments: true, audio_attachments: false
            )
          end
        end
      end
    end
  end
end
