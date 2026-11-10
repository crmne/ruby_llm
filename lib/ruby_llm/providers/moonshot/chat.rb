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
          raise ArgumentError, 'Moonshot does not accept calls: :one' if payload.delete(:parallel_tool_calls) == false

          payload[:thinking] = { type: thinking.enabled ? 'enabled' : 'disabled' } unless thinking&.enabled.nil?
          payload.merge!(prompt_cache_params(caching)) if caching
          payload
        end

        def count_tokens_url
          'tokenizers/estimate-token-count'
        end

        def render_count_tokens_payload(messages, model:, **)
          render_payload(messages, model:, temperature: nil, **).slice(:model, :messages, :tools, :response_format)
        end

        def parse_count_tokens_response(response)
          response.body.dig('data', 'total_tokens')
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
          return attachment.image? || attachment.video? if attachment.provider_file?

          attachment.video? || Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: :none, audio_attachments: false
          )
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            if attachment.image?
              render_inline_image(attachment)
            elsif attachment.video?
              render_inline_video(attachment)
            else
              Protocols::ChatCompletions::Media.render_attachment(
                attachment, document_attachments: :none, image_attachments: true, audio_attachments: false
              )
            end
          end
        end

        def render_inline_image(image)
          { type: 'image_url', image_url: { url: inline_url(image) } }
        end

        def render_inline_video(video)
          { type: 'video_url', video_url: { url: inline_url(video) } }
        end

        # Moonshot reads media only from data URIs and its own file references,
        # so remote files travel inline.
        def inline_url(attachment)
          attachment.provider_file? ? "ms://#{attachment.provider_file_id}" : attachment.for_llm
        end
      end
    end
  end
end
