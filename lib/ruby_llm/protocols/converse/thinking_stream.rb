# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Protocols
    class Converse
      class ThinkingStream # :nodoc: all
        def initialize
          @blocks = {}
        end

        def add(event)
          @blocks.clear if event.key?('messageStart')
          part = event['contentBlockStart'] || event['contentBlockDelta'] || event
          index = part['contentBlockIndex']
          return if index.nil?

          start = part.dig('start', 'reasoningContent')
          @blocks[index] = Support::Utils.deep_dup(start) if start
          delta = part.dig('delta', 'reasoningContent')
          append_delta(index, delta) if delta
        end

        def raw_reasoning
          return if @blocks.empty?

          { 'converse' => @blocks.sort.map { |_index, content| { 'reasoningContent' => content } } }
        end

        private

        def append_delta(index, delta)
          block = (@blocks[index] ||= {})
          if delta.key?('redactedContent')
            append_redacted(block, delta['redactedContent'])
          else
            text = (block['reasoningText'] ||= { 'text' => '' })
            (delta['reasoningText'] || delta).slice('text', 'signature').each do |key, value|
              text[key] = text[key].to_s + value.to_s
            end
          end
        end

        def append_redacted(block, data)
          block['redactedContent'] = if block['redactedContent']
                                       Base64.strict_encode64(Base64.decode64(block['redactedContent']) +
                                                              Base64.decode64(data))
                                     else
                                       data
                                     end
        end
      end
    end
  end
end
