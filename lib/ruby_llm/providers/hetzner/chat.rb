# frozen_string_literal: true

module RubyLLM
  module Providers
    class Hetzner
      # Chat methods of the Hetzner Inference API integration
      module Chat
        module_function

        def render_role(role)
          role.to_s
        end

        def supported_attachment?(attachment)
          Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: :none, audio_attachments: false
          )
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            if attachment.type == :image && !attachment.provider_file?
              render_inline_image(attachment)
            else
              Protocols::ChatCompletions::Media.render_attachment(
                attachment, document_attachments: :none, image_attachments: true, audio_attachments: false
              )
            end
          end
        end

        # Hetzner's servers can't fetch URLs, so remote images travel inline too.
        def render_inline_image(image)
          { type: 'image_url', image_url: { url: image.for_llm } }
        end
      end
    end
  end
end
