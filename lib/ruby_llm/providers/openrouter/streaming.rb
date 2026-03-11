# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Streaming methods of the OpenRouter API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          usage = data['usage'] || {}
          cached_tokens = usage.dig('prompt_tokens_details', 'cached_tokens')
          delta = data.dig('choices', 0, 'delta') || {}

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: delta['content'],
            thinking: Thinking.build(
              text: extract_thinking_text(delta),
              signature: extract_thinking_signature(delta)
            ),
            tool_calls: OpenAI::Tools.parse_tool_calls(delta['tool_calls'], parse_arguments: false),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0,
            thinking_tokens: usage.dig('completion_tokens_details', 'reasoning_tokens')
          )
        end

        def parse_streaming_error(data)
          OpenAI::Streaming.parse_streaming_error(data)
        end

        def extract_thinking_text(delta)
          candidate = delta['reasoning']
          return candidate if candidate.is_a?(String)

          details = delta['reasoning_details']
          return nil unless details.is_a?(Array)

          text = details.filter_map do |detail|
            case detail['type']
            when 'reasoning.text'
              detail['text']
            when 'reasoning.summary'
              detail['summary']
            end
          end.join

          text.empty? ? nil : text
        end

        def extract_thinking_signature(delta)
          details = delta['reasoning_details']
          return nil unless details.is_a?(Array)

          signature = details.filter_map do |detail|
            detail['signature'] if detail['signature'].is_a?(String)
          end.first
          return signature if signature

          encrypted = details.find { |detail| detail['type'] == 'reasoning.encrypted' && detail['data'].is_a?(String) }
          encrypted&.dig('data')
        end
      end
    end
  end
end
