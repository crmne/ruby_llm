# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Streaming methods of the OpenRouter API integration
      module Streaming
        ACCUMULATED_REASONING_KEYS = %w[text data summary].freeze

        module_function

        def build_chunk(data)
          usage = data['usage'] || {}
          delta = data.dig('choices', 0, 'delta') || {}

          Chunk.new(
            role: :assistant,
            model: data['model'],
            content: delta['content'],
            thinking: Thinking.build(
              text: extract_thinking_text(delta),
              signature: extract_thinking_signature(delta)
            ),
            raw_reasoning: accumulate_raw_reasoning(delta['reasoning_details']),
            tool_calls: parse_tool_calls(delta['tool_calls'], parse_arguments: false, stream_keys: true),
            input_tokens: input_tokens(usage),
            output_tokens: output_tokens(usage),
            cache_read_tokens: cache_read_tokens(usage),
            cache_write_tokens: cache_write_tokens(usage),
            thinking_tokens: thinking_tokens(usage),
            reported_cost: reported_cost(usage),
            finish_reason: normalize_finish_reason(data.dig('choices', 0, 'finish_reason'))
          )
        end

        def accumulate_raw_reasoning(details)
          return @raw_reasoning unless details.is_a?(Array) && !details.empty?

          @raw_reasoning ||= []
          details.each { |detail| merge_reasoning_detail(detail) }
          @raw_reasoning
        end

        def merge_reasoning_detail(detail)
          target = reasoning_detail_target(detail)
          return @raw_reasoning << detail.dup unless target

          detail.each do |key, value|
            if value.is_a?(String) && target[key].is_a?(String) && ACCUMULATED_REASONING_KEYS.include?(key)
              target[key] += value
            elsif target[key].nil?
              target[key] = value
            end
          end
        end

        def reasoning_detail_target(detail)
          index = detail['index']
          return nil unless index

          @raw_reasoning.find { |entry| entry['index'] == index && entry['type'] == detail['type'] }
        end
      end
    end
  end
end
