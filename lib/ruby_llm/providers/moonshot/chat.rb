# frozen_string_literal: true

module RubyLLM
  module Providers
    class Moonshot
      # Chat methods of the Moonshot AI API integration
      # https://platform.kimi.ai/docs/api/chat
      module Chat
        module_function

        def render_role(role)
          role.to_s
        end

        def max_output_tokens_field(_model)
          :max_completion_tokens
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          payload[:thinking] = { type: thinking.enabled ? 'enabled' : 'disabled' } unless thinking&.enabled.nil?
          payload.merge!(prompt_cache_params(caching)) if caching
          payload
        end

        def apply_end_user(payload, identifier)
          payload.merge(safety_identifier: identifier)
        end

        # Moonshot takes prompt_cache_key and prompt_cache_options, and
        # refuses the explicit cache breakpoints OpenAI accepts.
        def openai_prompt_caching?
          false
        end

        def render_thinking(msg)
          text = msg.thinking&.text if msg.role == :assistant
          text ? { reasoning_content: text } : {}
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

        # Moonshot reads images only from data URIs, so remote images travel inline.
        def render_inline_image(image)
          { type: 'image_url', image_url: { url: image.for_llm } }
        end
      end
    end
  end
end
