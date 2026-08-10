# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # Chat methods of the DeepSeek API integration
      module Chat
        REASONING_EFFORTS = %w[low high max].freeze

        module_function

        def format_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          configure_thinking_payload(payload, thinking)
          degrade_schema_payload(payload) if schema
          payload
        end

        def configure_thinking_payload(payload, thinking)
          return unless thinking&.enabled?

          if thinking.budget
            RubyLLM.logger.debug { "DeepSeek has no thinking budgets; ignoring budget #{thinking.budget}" }
          end

          if thinking.effort == 'none'
            payload.delete(:reasoning_effort)
            payload[:thinking] = { type: 'disabled' }
          else
            payload[:thinking] = { type: 'enabled' }
            effort = reasoning_effort_for(thinking.effort)
            payload[:reasoning_effort] = effort if effort
          end
        end

        def reasoning_effort_for(effort)
          return nil unless effort
          return effort if REASONING_EFFORTS.include?(effort)

          RubyLLM.logger.debug { "DeepSeek reasoning_effort accepts low, high, or max; coercing #{effort} to high" }
          'high'
        end

        def degrade_schema_payload(payload)
          RubyLLM.logger.warn(
            'DeepSeek does not support json_schema response formats. ' \
            'Falling back to json_object mode; the schema will not be enforced.'
          )
          payload[:response_format] = { type: 'json_object' }
        end

        def format_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          text = thinking&.text.to_s
          payload = { reasoning_content: text }
          payload[:reasoning] = text unless text.empty?
          payload[:reasoning_signature] = thinking.signature if thinking&.signature
          payload
        end

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_content(
            content,
            attachments,
            document_attachments: :none,
            image_attachments: false,
            audio_attachments: false
          )
        end
      end
    end
  end
end
