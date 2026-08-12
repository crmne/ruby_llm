# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # DeepSeek's dialect of the OpenAI Responses API, served for
      # deepseek-v4-flash. Reasoning arrives as reasoning_text content parts
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
      end
    end
  end
end
