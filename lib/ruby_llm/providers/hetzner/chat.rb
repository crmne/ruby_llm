# frozen_string_literal: true

module RubyLLM
  module Providers
    class Hetzner
      # Chat methods of the Hetzner Inference API integration
      module Chat
        module_function

        REJECTED_EFFORT = /\AUnexpected reasoning effort /

        def render_role(role)
          role.to_s
        end

        # The API accepts cache fields and ignores them; it caches long
        # prompts by itself.
        def openai_prompt_caching?
          false
        end

        def apply_prompt_cache_params(_payload, caching)
          prompt_cache_options(caching) if caching
        end

        # The API names a rejected effort only in its message.
        def parse_unsupported_parameter(response)
          super || (:thinking if parse_error(response).to_s.match?(REJECTED_EFFORT))
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
