# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Chat methods for Mistral API
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: format_content_with_thinking(msg),
              tool_calls: OpenAI::Tools.format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        # rubocop:disable Metrics/ParameterLists
        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil)
          payload = super
          payload.delete(:stream_options)
          payload.delete(:reasoning_effort)
          warn_on_unsupported_thinking(model, thinking)
          payload
        end
        # rubocop:enable Metrics/ParameterLists

        def format_content_with_thinking(msg)
          formatted_content = OpenAI::Media.format_content(msg.content)
          return formatted_content unless msg.role == :assistant && msg.thinking

          content_blocks = build_thinking_blocks(msg.thinking)
          append_formatted_content(content_blocks, formatted_content)

          content_blocks
        end

        def warn_on_unsupported_thinking(model, thinking)
          return unless thinking&.enabled?
          return if model.id.to_s.include?('magistral')

          RubyLLM.logger.warn(
            'Mistral thinking is only supported on Magistral models. ' \
            "Ignoring thinking settings for #{model.id}."
          )
        end

        def build_thinking_blocks(thinking)
          return [] unless thinking

          if thinking.text
            [{
              type: 'thinking',
              thinking: [{ type: 'text', text: thinking.text }],
              signature: thinking.signature
            }.compact]
          elsif thinking.signature
            [{ type: 'thinking', signature: thinking.signature }]
          else
            []
          end
        end

        def append_formatted_content(content_blocks, formatted_content)
          if formatted_content.is_a?(Array)
            content_blocks.concat(formatted_content)
          elsif formatted_content
            content_blocks << { type: 'text', text: formatted_content }
          end
        end
      end
    end
  end
end
