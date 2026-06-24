# frozen_string_literal: true

require 'base64'
require 'faraday'
require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Streaming implementation for Bedrock ConverseStream (AWS Event Stream).
      module Streaming
        ErrorResponse = Struct.new(:body, :status)

        private

        def stream_url
          "/model/#{escape_model_id(@model.id)}/converse-stream"
        end

        def stream_response(payload, additional_headers = {}, &block)
          accumulator = StreamAccumulator.new
          decoder = event_stream_decoder
          body = JSON.generate(payload)

          response = @connection.post(stream_url, payload) do |req|
            req.headers.merge!(@provider.sign_headers('POST', stream_url, body))
            req.headers.merge!(additional_headers) unless additional_headers.empty?
            req.headers['Accept'] = 'application/vnd.amazon.eventstream'

            if Faraday::VERSION.start_with?('1')
              req.options[:on_data] = proc do |chunk, _size|
                parse_stream_chunk(decoder, chunk, accumulator, &block)
              end
            else
              req.options.on_data = proc do |chunk, _bytes, env|
                if env&.status == 200
                  parse_stream_chunk(decoder, chunk, accumulator, &block)
                else
                  handle_failed_stream(chunk, env)
                end
              end
            end
          end

          message = accumulator.to_message(response)
          RubyLLM.logger.debug { "Stream completed: #{message.content}" }
          message
        end

        def event_stream_decoder
          require 'aws-eventstream'
          Aws::EventStream::Decoder.new
        rescue LoadError
          raise Error,
                'The aws-eventstream gem is required for Bedrock streaming. ' \
                'Please add it to your Gemfile: gem "aws-eventstream"'
        end

        def handle_failed_stream(chunk, env)
          data = JSON.parse(chunk)
          error_response = env.merge(body: data)
          ErrorMiddleware.parse_error(provider: self, response: error_response)
        rescue JSON::ParserError
          RubyLLM.logger.debug { "Failed Bedrock stream error chunk: #{chunk}" }
        end

        def parse_stream_chunk(decoder, raw_chunk, accumulator)
          handle_non_eventstream_error_chunk(raw_chunk)

          decode_events(decoder, raw_chunk).each do |event|
            chunk = build_chunk(event)
            next unless chunk

            accumulator.add(chunk)
            yield chunk
          end
        end

        def handle_non_eventstream_error_chunk(raw_chunk)
          text = raw_chunk.to_s

          if text.start_with?('event: error')
            payload = text.lines.find { |line| line.start_with?('data:') }&.delete_prefix('data:')&.strip
            raise_streaming_chunk_error(payload) if payload
            return
          end

          return unless text.lstrip.start_with?('{') && text.include?('"error"')

          raise_streaming_chunk_error(text)
        end

        def raise_streaming_chunk_error(payload)
          parsed = JSON.parse(payload)
          message = parsed.dig('error', 'message') || parsed['message'] || 'Bedrock streaming error'
          response = ErrorResponse.new({ 'message' => message }, 500)
          ErrorMiddleware.parse_error(provider: self, response: response)
        rescue JSON::ParserError
          nil
        end

        def decode_events(decoder, raw_chunk)
          events = []
          message, eof = decoder.decode_chunk(raw_chunk)

          while message
            event = decode_event_payload(message.payload.read)
            if event && RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug do
                "Bedrock stream event keys: #{event.keys}"
              end
            end
            events << event if event
            break if eof

            message, eof = decoder.decode_chunk
          end

          events
        end

        def decode_event_payload(payload)
          outer = JSON.parse(payload)

          if outer['bytes'].is_a?(String)
            JSON.parse(Base64.decode64(outer['bytes']))
          else
            outer
          end
        rescue JSON::ParserError => e
          RubyLLM.logger.debug { "Failed to decode Bedrock stream event payload: #{e.message}" }
          nil
        end

        def build_chunk(event)
          raise_stream_error(event) if stream_error_event?(event)

          metadata_usage, usage = event_usage(event)

          Chunk.new(
            role: :assistant,
            model_id: event['modelId'] || @model&.id,
            content: extract_content_delta(event),
            thinking: Thinking.build(
              text: extract_thinking_delta(event),
              signature: extract_thinking_signature(event)
            ),
            tool_calls: extract_tool_calls(event),
            input_tokens: extract_input_tokens(metadata_usage, usage),
            output_tokens: extract_output_tokens(metadata_usage, usage),
            cached_tokens: extract_cached_tokens(metadata_usage, usage),
            cache_creation_tokens: extract_cache_creation_tokens(metadata_usage, usage),
            thinking_tokens: extract_reasoning_tokens(metadata_usage, usage),
            finish_reason: extract_finish_reason(event)
          )
        end

        def extract_finish_reason(event)
          event.dig('messageStop', 'stopReason') || event['stopReason']
        end

        def event_usage(event)
          [
            event.dig('metadata', 'usage') || {},
            event['usage'] || {}
          ]
        end

        def extract_input_tokens(metadata_usage, usage)
          bedrock_usage = metadata_usage['inputTokens'] ? metadata_usage : usage
          Chat.input_tokens(bedrock_usage) if bedrock_usage['inputTokens']
        end

        def extract_output_tokens(metadata_usage, usage)
          metadata_usage['outputTokens'] || usage['outputTokens']
        end

        def extract_cached_tokens(metadata_usage, usage)
          metadata_usage['cacheReadInputTokens'] || usage['cacheReadInputTokens']
        end

        def extract_cache_creation_tokens(metadata_usage, usage)
          metadata_usage['cacheWriteInputTokens'] || usage['cacheWriteInputTokens']
        end

        def extract_reasoning_tokens(metadata_usage, usage)
          Chat.reasoning_tokens(metadata_usage) || Chat.reasoning_tokens(usage)
        end

        def stream_error_event?(event)
          event.keys.any? { |key| key.end_with?('Exception') } || event['type'] == 'error'
        end

        def raise_stream_error(event)
          if event['type'] == 'error'
            message = event.dig('error', 'message') || 'Bedrock streaming error'
            response = ErrorResponse.new({ 'message' => message }, 500)
            ErrorMiddleware.parse_error(provider: self, response: response)
            return
          end

          key = event.keys.find { |candidate| candidate.end_with?('Exception') }
          payload = event[key]
          message = payload['message'] || key
          status = case key
                   when 'throttlingException' then 429
                   when 'validationException' then 400
                   when 'accessDeniedException', 'unrecognizedClientException' then 401
                   when 'serviceUnavailableException' then 503
                   else 500
                   end

          response = ErrorResponse.new({ 'message' => message }, status)
          ErrorMiddleware.parse_error(provider: self, response: response)
        end

        def extract_content_delta(event)
          normalized_delta(event)['text']
        end

        def extract_thinking_delta(event)
          reasoning_content = normalized_delta(event)['reasoningContent'] || {}

          reasoning_text = reasoning_content['reasoningText'] || {}
          reasoning_text['text'] || reasoning_content['text']
        end

        def extract_thinking_signature(event)
          signature = extract_signature_from_delta(event)
          return signature if signature

          signature = extract_signature_from_start(event)
          return signature if signature

          nil
        end

        def extract_signature_from_delta(event)
          reasoning_content = normalized_delta(event)['reasoningContent'] || {}
          reasoning_text = reasoning_content['reasoningText'] || {}
          reasoning_text['signature'] || reasoning_content['signature']
        end

        def extract_signature_from_start(event)
          start = event.dig('contentBlockStart', 'start', 'reasoningContent')
          return nil unless start

          reasoning_text = start['reasoningText'] || {}
          return reasoning_text['signature'] if reasoning_text['signature']
          return start['redactedContent'] if start['redactedContent']

          nil
        end

        def extract_tool_calls(event)
          return extract_tool_call_start(event) if tool_call_start_event?(event)
          return extract_tool_call_delta(event) if tool_call_delta_event?(event)

          nil
        end

        def tool_call_start_event?(event)
          event['contentBlockStart'] || event['start']
        end

        def tool_call_delta_event?(event)
          event['contentBlockDelta'] || event.dig('delta', 'toolUse')
        end

        def extract_tool_call_start(event)
          tool_use = event.dig('contentBlockStart', 'start', 'toolUse') || event.dig('start', 'toolUse')
          return nil unless tool_use

          tool_use_id = tool_use['toolUseId']
          {
            tool_use_id => ToolCall.new(
              id: tool_use_id,
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          }
        end

        def extract_tool_call_delta(event)
          input = normalized_delta(event).dig('toolUse', 'input')
          return nil unless input

          { nil => ToolCall.new(id: nil, name: nil, arguments: input) }
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
