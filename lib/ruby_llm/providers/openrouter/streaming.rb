# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Streaming methods of the OpenRouter API integration
      module Streaming
        ACCUMULATED_REASONING_KEYS = %w[text data summary].freeze

        module_function

        def accumulate_raw_reasoning(delta)
          details = delta['reasoning_details']
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
              target[key] = +target[key]
              target[key] << value
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
