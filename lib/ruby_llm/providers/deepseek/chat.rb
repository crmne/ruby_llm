# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # Chat methods of the DeepSeek API integration
      module Chat
        module_function

        def render_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          raise ArgumentError, 'DeepSeek Chat Completions cannot enforce a schema. Use protocol: :responses.' if schema

          payload = super
          configure_thinking_payload(payload, thinking)
          payload
        end

        def apply_end_user(payload, identifier)
          payload.merge(user_id: identifier)
        end

        def configure_thinking_payload(payload, thinking)
          return unless thinking&.enabled?

          raise ArgumentError, 'DeepSeek has no thinking budget; use effort:' if thinking.budget

          if thinking.disabled?
            payload.delete(:reasoning_effort)
            payload[:thinking] = { type: 'disabled' }
          else
            payload[:thinking] = { type: 'enabled' }
          end
        end

        def render_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          text = thinking&.text.to_s
          payload = { reasoning_content: text }
          payload[:reasoning] = text unless text.empty?
          payload[:reasoning_signature] = thinking.signature if thinking&.signature
          payload
        end

        def supported_attachment?(attachment)
          Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: :none, audio_attachments: false
          )
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_content(
            content,
            attachments,
            document_attachments: :none,
            audio_attachments: false
          )
        end
      end
    end
  end
end
