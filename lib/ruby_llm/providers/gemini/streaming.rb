# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class Gemini
      # Streaming methods for the Gemini API implementation
      module Streaming
        def stream_url
          "models/#{@model}:streamGenerateContent?alt=sse"
        end

        def build_chunk(data)
          parts = data.dig('candidates', 0, 'content', 'parts') || []

          Chunk.new(
            role: :assistant,
            model_id: data['modelVersion'],
            content: extract_text_content(parts),
            thinking: Thinking.build(
              text: extract_thought_parts(parts),
              signature: extract_thought_signature(parts)
            ),
            input_tokens: input_tokens(data),
            output_tokens: extract_output_tokens(data),
            cached_tokens: data.dig('usageMetadata', 'cachedContentTokenCount'),
            thinking_tokens: data.dig('usageMetadata', 'thoughtsTokenCount'),
            tool_calls: extract_tool_calls(data)
          )
        end

        private

        def extract_text_content(parts)
          text_parts = parts.reject { |p| p['thought'] }
          text = text_parts.filter_map { |p| p['text'] }.join
          text.empty? ? nil : text
        end

        def extract_output_tokens(data)
          candidates = data.dig('usageMetadata', 'candidatesTokenCount') || 0
          thoughts = data.dig('usageMetadata', 'thoughtsTokenCount') || 0
          total = candidates + thoughts
          total.positive? ? total : nil
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          [error_data['error']['code'], error_data['error']['message']]
        rescue JSON::ParserError => e
          RubyLLM.logger.debug { "Failed to parse streaming error: #{e.message}" }
          [500, "Failed to parse error: #{data}"]
        end
      end
    end
  end
end
