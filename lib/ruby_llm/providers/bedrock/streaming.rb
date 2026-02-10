# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Streaming implementation for Bedrock ConverseStream (AWS Event Stream).
      module Streaming
        private

        def stream_url
          "/model/#{@model.id}/converse-stream"
        end

        def stream_response(connection, payload, additional_headers = {}, &block)
          accumulator = StreamAccumulator.new
          decoder = event_stream_decoder
          request_payload = api_payload(payload)
          body = JSON.generate(request_payload)

          response = connection.post(stream_url, request_payload) do |req|
            req.headers.merge!(sign_headers('POST', stream_url, body))
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
          RubyLLM.logger.debug "Stream completed: #{message.content}"
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
          RubyLLM.logger.debug "Failed Bedrock stream error chunk: #{chunk}"
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
          response = Struct.new(:body, :status).new({ 'message' => message }, 500)
          ErrorMiddleware.parse_error(provider: self, response: response)
        rescue JSON::ParserError
          nil
        end

        def decode_events(decoder, raw_chunk)
          events = []
          message, eof = decoder.decode_chunk(raw_chunk)

          while message
            event = decode_event_payload(message.payload.read)
            RubyLLM.logger.debug("Bedrock stream event keys: #{event.keys}") if event && RubyLLM.config.log_stream_debug
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
          RubyLLM.logger.debug "Failed to decode Bedrock stream event payload: #{e.message}"
          nil
        end

        def build_chunk(event)
          raise_stream_error(event) if stream_error_event?(event)

          metadata_usage, usage, message_usage = event_usage(event)

          Chunk.new(
            role: :assistant,
            model_id: event['modelId'] || event.dig('message', 'model') || @model&.id,
            content: extract_content_delta(event),
            thinking: Thinking.build(
              text: extract_thinking_delta(event),
              signature: extract_thinking_signature(event)
            ),
            tool_calls: extract_tool_calls(event),
            input_tokens: extract_input_tokens(metadata_usage, usage, message_usage),
            output_tokens: extract_output_tokens(metadata_usage, usage),
            cached_tokens: extract_cached_tokens(metadata_usage, usage),
            cache_creation_tokens: extract_cache_creation_tokens(metadata_usage, usage),
            thinking_tokens: extract_reasoning_tokens(metadata_usage, usage)
          )
        end

        def event_usage(event)
          [
            event.dig('metadata', 'usage') || {},
            event['usage'] || {},
            event.dig('message', 'usage') || {}
          ]
        end

        def extract_input_tokens(metadata_usage, usage, message_usage)
          metadata_usage['inputTokens'] || usage['inputTokens'] || message_usage['input_tokens']
        end

        def extract_output_tokens(metadata_usage, usage)
          metadata_usage['outputTokens'] || usage['outputTokens'] || usage['output_tokens']
        end

        def extract_cached_tokens(metadata_usage, usage)
          metadata_usage['cacheReadInputTokens'] || usage['cacheReadInputTokens'] || usage['cache_read_input_tokens']
        end

        def extract_cache_creation_tokens(metadata_usage, usage)
          metadata_usage['cacheWriteInputTokens'] || usage['cacheWriteInputTokens'] ||
            usage['cache_creation_input_tokens']
        end

        def extract_reasoning_tokens(metadata_usage, usage)
          metadata_usage['reasoningTokens'] || usage['reasoningTokens'] ||
            usage.dig('output_tokens_details', 'thinking_tokens')
        end

        def stream_error_event?(event)
          event.keys.any? { |key| key.end_with?('Exception') } || event['type'] == 'error'
        end

        def raise_stream_error(event)
          if event['type'] == 'error'
            message = event.dig('error', 'message') || 'Bedrock streaming error'
            response = Struct.new(:body, :status).new({ 'message' => message }, 500)
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

          response = Struct.new(:body, :status).new({ 'message' => message }, status)
          ErrorMiddleware.parse_error(provider: self, response: response)
        end

        def extract_content_delta(event)
          delta = normalized_delta(event)
          return delta['text'] if delta['text']

          return event.dig('delta', 'text') if event.dig('delta', 'type') == 'text_delta'

          nil
        end

        def extract_thinking_delta(event)
          delta = normalized_delta(event)
          reasoning_content = delta['reasoningContent'] || {}

          reasoning_text = reasoning_content['reasoningText'] || {}
          return reasoning_text['text'] if reasoning_text['text']
          return event.dig('delta', 'thinking') if event.dig('delta', 'type') == 'thinking_delta'

          nil
        end

        def extract_thinking_signature(event)
          signature = extract_signature_from_delta(event)
          return signature if signature

          signature = extract_signature_from_start(event)
          return signature if signature

          nil
        end

        def extract_signature_from_delta(event)
          delta = normalized_delta(event)
          reasoning_content = delta['reasoningContent'] || {}
          reasoning_text = reasoning_content['reasoningText'] || {}
          return reasoning_text['signature'] if reasoning_text['signature']
          return event.dig('delta', 'signature') if event.dig('delta', 'type') == 'signature_delta'

          nil
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
          event['contentBlockStart'] || event['start'] || event.dig('content_block', 'tool_use')
        end

        def tool_call_delta_event?(event)
          event['contentBlockDelta'] || event.dig('delta', 'toolUse') || event.dig('delta', 'tool_use') ||
            event.dig('delta', 'partial_json')
        end

        def extract_tool_call_start(event)
          tool_use = event.dig('contentBlockStart', 'start', 'toolUse')
          tool_use ||= event.dig('start', 'toolUse')
          tool_use ||= event.dig('content_block', 'tool_use') if event['type'] == 'content_block_start'
          return nil unless tool_use

          tool_use_id = tool_use['toolUseId'] || tool_use['id']
          tool_name = tool_use['name']
          tool_input = tool_use['input'] || {}

          {
            tool_use_id => ToolCall.new(
              id: tool_use_id,
              name: tool_name,
              arguments: tool_input
            )
          }
        end

        def extract_tool_call_delta(event)
          input = normalized_delta(event).dig('toolUse', 'input')
          input ||= normalized_delta(event).dig('tool_use', 'input')
          input ||= event.dig('delta', 'partial_json') if event.dig('delta', 'type') == 'input_json_delta'
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
