# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Gemini
      # Streaming methods for the Gemini API implementation
      module Streaming
        def stream_url
          "models/#{@model.id}:streamGenerateContent?alt=sse"
        end

        def build_chunk(data)
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          track_stream_parts(data, parts)

          Chunk.new(
            role: :assistant,
            model: data['modelVersion'],
            content: extract_text_content(parts),
            citations: extract_citations(data, nil),
            thinking: Thinking.build(
              text: extract_thought_parts(parts),
              signature: extract_thought_signature(parts)
            ),
            input_tokens: input_tokens(data),
            output_tokens: extract_output_tokens(data),
            cache_read_tokens: data.dig('usageMetadata', 'cachedContentTokenCount'),
            thinking_tokens: data.dig('usageMetadata', 'thoughtsTokenCount'),
            finish_reason: data.dig('candidates', 0, 'finishReason') || data.dig('promptFeedback', 'blockReason'),
            tool_calls: extract_tool_calls(data),
            **stream_end_fields(data)
          )
        end

        private

        # Accumulates streamed parts so code-execution turns can be replayed
        # verbatim, mirroring the non-streaming path.
        def track_stream_parts(data, parts)
          @stream_parts = (@stream_parts || []).concat(parts)
          @saw_server_part = true if parts.any? { |part| server_tool_part?(part) }
          metadata_calls = metadata_server_tool_calls(data)
          @stream_metadata_calls = metadata_calls if metadata_calls.any?
        end

        def stream_end_fields(data)
          return {} unless data.dig('candidates', 0, 'finishReason')

          part_calls = @stream_parts.to_a.select { |part| server_tool_part?(part) }.map do |part|
            ServerToolCall.new(
              type: part.key?('executableCode') ? 'executable_code' : 'code_execution_result',
              input: part['executableCode'],
              result: part['codeExecutionResult'],
              raw: part
            )
          end
          calls = part_calls + @stream_metadata_calls.to_a
          return {} if calls.empty?

          {
            server_tool_calls: calls,
            raw_content: @saw_server_part ? @stream_parts : nil
          }
        end

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
          error = error_data.is_a?(Hash) ? error_data['error'] || error_data : error_data
          return [nil, error.to_s] unless error.is_a?(Hash)

          [error['code'], error['message']]
        rescue JSON::ParserError => e
          RubyLLM.logger.debug { "Failed to parse streaming error: #{e.message}" }
          [500, "Failed to parse error: #{data}"]
        end
      end
    end
  end
end
