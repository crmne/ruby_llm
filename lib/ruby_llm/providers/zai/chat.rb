# frozen_string_literal: true

module RubyLLM
  module Providers
    class ZAI
      # Chat methods of the Z.ai API integration
      # https://docs.z.ai/api-reference/llm/chat-completion
      module Chat
        FINISH_REASONS = Protocols::ChatCompletions::Chat::FINISH_REASONS.merge(
          'sensitive' => :content_filter,
          'model_context_window_exceeded' => :max_tokens
        ).freeze

        module_function

        def finish_reasons = FINISH_REASONS

        def render_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          payload[:thinking] = { type: thinking.disabled? ? 'disabled' : 'enabled' } if thinking&.enabled?
          payload.delete(:reasoning_effort) if thinking&.disabled?
          payload
        end

        def apply_end_user(payload, identifier)
          payload.merge(user_id: identifier)
        end

        # Z.ai caches prompt prefixes by itself and takes no cache controls.
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
          Protocols::ChatCompletions::Media.render_content(
            content, attachments, document_attachments: :none, audio_attachments: false
          )
        end
      end
    end
  end
end
