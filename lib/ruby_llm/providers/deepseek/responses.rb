# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # DeepSeek's dialect of the OpenAI Responses API.
      # Reasoning arrives as reasoning_text content parts
      # instead of summaries, both in responses and in the stream.
      class Responses < Protocols::Responses
        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } },
          apply_patch: { tool: { type: 'custom', name: 'apply_patch' } }
        }.freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def apply_end_user(payload, identifier)
          payload.merge(user_id: identifier)
        end

        def build_chunk(data)
          return chunk(thinking: Thinking.build(text: data['delta'])) if data['type'] == 'response.reasoning_text.delta'

          super
        end

        def parse_reasoning_summary(output)
          texts = output.select { |item| item['type'] == 'reasoning' }.flat_map do |item|
            Array(item['content']).filter_map { |part| part['text'] if part['type'] == 'reasoning_text' }
          end

          texts.empty? ? super : texts.join("\n")
        end

        def format_assistant_items(message)
          items = super
          return items if message.raw_content || message.thinking&.text.to_s.empty? || message.thinking.signature

          items.unshift(format_reasoning_item(message.thinking))
        end

        def format_reasoning_item(thinking)
          { type: 'reasoning', content: [{ type: 'reasoning_text', text: thinking.text }] }
        end

        def format_tool_items(message)
          [{
            type: 'function_call_output',
            call_id: message.tool_call_id,
            output: format_content(message.content, message.attachments)
          }]
        end

        def format_provider_file(file)
          raise UnsupportedAttachmentError, file.mime_type unless file.image?

          { type: 'input_image', file_id: file.provider_file_id }
        end

        def format_document(document)
          raise UnsupportedAttachmentError, document.mime_type
        end
      end
    end
  end
end
