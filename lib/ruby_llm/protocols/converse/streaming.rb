# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Streaming implementation for Bedrock ConverseStream (AWS Event Stream).
      module Streaming
        include Protocols::Bedrock::EventStream

        private

        def stream_url
          "/model/#{escape_model_id(@model.id)}/converse-stream"
        end

        def stream_response(payload, additional_headers = {}, &block)
          @thinking_stream = ThinkingStream.new
          @stream_text_lengths = Hash.new(0)
          @stream_citations = {}
          accumulator = RubyLLM::Protocol::StreamAccumulator.new

          response = stream_events(stream_url, JSON.generate(payload), additional_headers) do |event|
            chunk = build_chunk(event)
            accumulator.add(chunk)
            block.call(chunk)
          end

          message = accumulator.to_message(response)
          RubyLLM.logger.debug { "Stream completed: #{message.content}" }
          message
        end

        def build_chunk(event)
          raise_stream_error(event) if stream_error_event?(event)

          metadata_usage, usage = event_usage(event)

          Chunk.new(
            role: :assistant,
            model: event['modelId'] || @model&.id,
            content: parse_content_delta(event),
            citations: parse_block_citations(event),
            thinking: Thinking.build(
              text: parse_thinking_delta(event),
              signature: parse_thinking_signature(event)
            ),
            raw_reasoning: streamed_thinking_blocks(event),
            tool_calls: extract_tool_calls(event),
            server_tool_calls: parse_server_tool_call_events(event),
            input_tokens: parse_input_tokens(metadata_usage, usage),
            output_tokens: parse_output_tokens(metadata_usage, usage),
            cache_read_tokens: parse_cache_read_tokens(metadata_usage, usage),
            cache_write_tokens: parse_cache_write_tokens(metadata_usage, usage),
            cache_write_tokens_by_ttl: Chat.cache_write_by_ttl(metadata_usage) || Chat.cache_write_by_ttl(usage),
            thinking_tokens: parse_reasoning_tokens(metadata_usage, usage),
            finish_reason: parse_finish_reason(event)
          )
        end

        def streamed_thinking_blocks(event)
          @thinking_stream ||= ThinkingStream.new
          @thinking_stream.add(event)
          @thinking_stream.raw_reasoning if event.key?('messageStop') || event.key?('stopReason')
        end

        def parse_finish_reason(event)
          normalize_finish_reason(event.dig('messageStop', 'stopReason') || event['stopReason'])
        end

        def event_usage(event)
          [
            event.dig('metadata', 'usage') || {},
            event['usage'] || {}
          ]
        end

        def parse_input_tokens(metadata_usage, usage)
          bedrock_usage = metadata_usage['inputTokens'] ? metadata_usage : usage
          Chat.input_tokens(bedrock_usage) if bedrock_usage['inputTokens']
        end

        def parse_output_tokens(metadata_usage, usage)
          metadata_usage['outputTokens'] || usage['outputTokens']
        end

        def parse_cache_read_tokens(metadata_usage, usage)
          metadata_usage['cacheReadInputTokens'] || usage['cacheReadInputTokens']
        end

        def parse_cache_write_tokens(metadata_usage, usage)
          metadata_usage['cacheWriteInputTokens'] || usage['cacheWriteInputTokens']
        end

        def parse_reasoning_tokens(metadata_usage, usage)
          Chat.reasoning_tokens(metadata_usage) || Chat.reasoning_tokens(usage)
        end

        def parse_content_delta(event)
          normalized_delta(event)['text']
        end

        # A citation delta arrives before the text it supports, so a block's
        # citations wait for the block to stop and take its span of the response.
        # A block still open when the message stops gives up what it has.
        def parse_block_citations(event)
          track_citation_block(event)
          finished_citation_blocks(event).flat_map { |index| take_block_citations(index) }
        end

        def track_citation_block(event)
          @stream_text_lengths ||= Hash.new(0)
          @stream_citations ||= {}
          index = event_block_index(event)
          return unless index

          delta = normalized_delta(event)
          @stream_text_lengths[index] += delta['text'].length if delta['text'].is_a?(String)
          (@stream_citations[index] ||= []) << delta['citation'] if delta['citation'].is_a?(Hash)
        end

        def finished_citation_blocks(event)
          return @stream_citations.keys.sort if event.key?('messageStop') || event.key?('stopReason')
          return [] if %w[delta start contentBlockDelta contentBlockStart].any? { |key| event.key?(key) }

          [event_block_index(event)].compact
        end

        def take_block_citations(index)
          length = @stream_text_lengths[index]
          start_index = @stream_text_lengths.sum { |block_index, size| block_index < index ? size : 0 }
          span = length.zero? ? {} : { start_index:, end_index: start_index + length }

          Array(@stream_citations.delete(index)).map { |citation| Chat.parse_citation(citation, **span) }
        end

        def parse_thinking_delta(event)
          reasoning_content = normalized_delta(event)['reasoningContent'] || {}

          reasoning_text = reasoning_content['reasoningText'] || {}
          return reasoning_text['text'] if reasoning_text.key?('text')
          return reasoning_content['text'] if reasoning_content.key?('text')
          return '' if [reasoning_text, reasoning_content].any? { |block| block.key?('signature') }

          parse_thinking_from_start(event)
        end

        def parse_thinking_from_start(event)
          start = event.dig('contentBlockStart', 'start', 'reasoningContent') || {}
          return unless start.key?('reasoningText')

          start.dig('reasoningText', 'text').to_s
        end

        def parse_thinking_signature(event)
          signature = parse_signature_from_delta(event)
          return signature if signature

          signature = parse_signature_from_start(event)
          return signature if signature

          nil
        end

        def parse_signature_from_delta(event)
          reasoning_content = normalized_delta(event)['reasoningContent'] || {}
          reasoning_text = reasoning_content['reasoningText'] || {}
          reasoning_text['signature'] || reasoning_content['signature'] || reasoning_content['redactedContent']
        end

        def parse_signature_from_start(event)
          start = event.dig('contentBlockStart', 'start', 'reasoningContent')
          return nil unless start

          reasoning_text = start['reasoningText'] || {}
          return reasoning_text['signature'] if reasoning_text['signature']
          return start['redactedContent'] if start['redactedContent']

          nil
        end

        def extract_tool_calls(event)
          return parse_tool_call_start(event) if tool_call_start_event?(event)
          return parse_tool_call_delta(event) if tool_call_delta_event?(event)

          nil
        end

        def tool_call_start_event?(event)
          event['contentBlockStart'] || event['start']
        end

        def tool_call_delta_event?(event)
          event['contentBlockDelta'] || event.dig('delta', 'toolUse')
        end

        def parse_tool_call_start(event)
          tool_use = event.dig('contentBlockStart', 'start', 'toolUse') || event.dig('start', 'toolUse')
          return nil unless tool_use

          if Chat.server_tool_use?(tool_use)
            remember_server_tool_block(event)
            return nil
          end

          tool_use_id = tool_use['toolUseId']
          {
            event_block_index(event) => ToolCall.new(
              provider_call_id: tool_use_id,
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          }
        end

        def parse_tool_call_delta(event)
          return nil if server_tool_block_event?(event)

          input = normalized_delta(event).dig('toolUse', 'input')
          return nil unless input

          { event_block_index(event) => ToolCall.new(name: nil, arguments: input) }
        end

        # Server-executed tool steps stream as typed toolUse and toolResult
        # block starts. Their input deltas are not function-call arguments,
        # so the block index is remembered and its deltas skipped.
        def parse_server_tool_call_events(event)
          start = event.dig('contentBlockStart', 'start') || event['start']
          return [] unless start.is_a?(Hash)

          tool_use = start['toolUse']
          tool_result = start['toolResult']
          if tool_use && Chat.server_tool_use?(tool_use)
            [ServerToolCall.new(type: tool_use['type'], name: tool_use['name'], id: tool_use['toolUseId'],
                                input: tool_use['input'], raw: start)]
          elsif tool_result && Chat.server_tool_result?(tool_result)
            [ServerToolCall.new(type: tool_result['type'], id: tool_result['toolUseId'],
                                result: tool_result['content'], raw: start)]
          else
            []
          end
        end

        def remember_server_tool_block(event)
          index = event_block_index(event)
          return if index.nil?

          @server_tool_block_indices ||= {}
          @server_tool_block_indices[index] = true
        end

        def server_tool_block_event?(event)
          index = event_block_index(event)
          !index.nil? && @server_tool_block_indices&.key?(index)
        end

        def event_block_index(event)
          event['contentBlockIndex'] ||
            event.dig('contentBlockStart', 'contentBlockIndex') ||
            event.dig('contentBlockDelta', 'contentBlockIndex')
        end

        def normalized_delta(event)
          delta = event.dig('contentBlockDelta', 'delta') || event['delta'] || {}
          return delta if delta.is_a?(Hash)

          if delta.is_a?(String) && !delta.empty?
            JSON.parse(delta)
          else
            {}
          end
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
