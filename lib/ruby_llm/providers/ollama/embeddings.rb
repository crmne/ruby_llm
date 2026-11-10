# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Ollama embeds text, an image, and audio together when the input is
      # one object holding each as a field.
      module Embeddings
        EMBEDDING_MEDIA_FIELDS = %i[image audio].freeze

        module_function

        def embedding_media?
          true
        end

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          input = with.any? ? media_embedding_input(text, with) : text
          super(input, model:, dimensions:, task_type:, title:, provider_options:)
        end

        def media_embedding_input(text, attachments)
          raise ArgumentError, 'embed one text at a time when embedding attachments' if text.is_a?(Array)

          input = text.to_s.empty? ? {} : { text: text }
          attachments.each do |attachment|
            unless EMBEDDING_MEDIA_FIELDS.include?(attachment.type)
              raise UnsupportedAttachmentError,
                    attachment.mime_type
            end
            raise ArgumentError, "Ollama embeds one #{attachment.type} per input" if input.key?(attachment.type)

            input[attachment.type] = attachment.encoded
          end
          input
        end
      end
    end
  end
end
