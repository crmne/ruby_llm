# frozen_string_literal: true

require 'base64'
require 'json'

module RubyLLM
  module Protocols
    module Bedrock
      # AWS event stream framing for Bedrock's streaming APIs, ConverseStream
      # and InvokeModelWithResponseStream. Each frame carries one JSON event,
      # bare or base64-encoded under "bytes", or an error.
      module EventStream
        ErrorResponse = Struct.new(:body, :status)

        EXCEPTION_STATUSES = {
          'throttlingException' => 429,
          'validationException' => 400,
          'accessDeniedException' => 401,
          'unrecognizedClientException' => 401,
          'serviceUnavailableException' => 503
        }.freeze

        private

        # Posts +body+ as an event stream request, yielding each decoded
        # event Hash and raising the errors the stream reports. Returns the
        # Faraday response.
        def stream_events(url, body, additional_headers = {}, &handler)
          decoder = event_stream_decoder
          progress = {}

          on_data = RubyLLM::Protocol::Streaming::FaradayHandlers.build(
            faraday_v1: faraday_1?,
            on_chunk: ->(chunk, _env) { parse_stream_chunk(decoder, chunk, progress, &handler) },
            on_failed_response: ->(chunk, env) { handle_failed_stream(chunk, env) }
          )

          on_reset = -> { decoder = event_stream_decoder }
          post_stream(url, body, on_data:, progress:, on_reset:) do |req|
            req.headers.merge!(additional_headers) unless additional_headers.empty?
            req.headers['Accept'] = 'application/vnd.amazon.eventstream'
          end
        end

        def event_stream_decoder
          require 'aws-eventstream'
          Aws::EventStream::Decoder.new
        rescue LoadError
          raise Error,
                'The aws-eventstream gem is required for Bedrock streaming. ' \
                'Please add it to your Gemfile: gem "aws-eventstream"'
        end

        # The error body arrives in as many reads as the adapter hands out, so
        # it accumulates on the env, which ErrorMiddleware clears per attempt.
        def handle_failed_stream(chunk, env)
          buffer = failed_stream_buffer(env)
          buffer << chunk
          error_response = env.merge(body: JSON.parse(buffer))
          Transport::ErrorMiddleware.parse_error(provider: self, response: error_response)
        rescue JSON::ParserError
          RubyLLM.logger.debug { "Accumulating Bedrock stream error chunk: #{chunk}" }
        end

        def failed_stream_buffer(env)
          (env[:streaming_state] ||= RubyLLM::Protocol::Streaming::StreamState.new).buffer
        end

        def parse_stream_chunk(decoder, raw_chunk, progress)
          handle_non_eventstream_error_chunk(raw_chunk)

          decode_events(decoder, raw_chunk).each do |event|
            raise_stream_error(event) if stream_error_event?(event)

            progress[:started] = true
            yield event
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
          message = chunk_error_message(JSON.parse(payload)) || 'Bedrock streaming error'
          response = ErrorResponse.new({ 'message' => message }, 500)
          Transport::ErrorMiddleware.parse_error(provider: self, response: response)
        rescue JSON::ParserError
          nil
        end

        def chunk_error_message(parsed)
          return unless parsed.is_a?(Hash)

          error = parsed['error']
          (error.is_a?(Hash) ? error['message'] : error) || parsed['message']
        end

        def decode_events(decoder, raw_chunk)
          events = []
          message, eof = decoder.decode_chunk(raw_chunk)

          while message
            event = decode_event(message)
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
        rescue Aws::EventStream::Errors::PreludeChecksumError
          raise_streaming_chunk_error(raw_chunk)
          raise Error, 'Bedrock returned an unreadable event stream'
        end

        # Modeled errors arrive as a frame after the 200, with the type in the
        # frame headers and a bare message as the payload. Rewrap it under the
        # exception name so raise_stream_error classifies it instead of the
        # frame passing for an empty event.
        def decode_event(message)
          return decode_error_frame(message.headers) if stream_error_frame?(message)

          exception_type = stream_exception_type(message)
          payload = message.payload.read
          event = decode_event_payload(payload)
          return event unless exception_type

          { exception_type => event || { 'message' => payload.to_s } }
        end

        # Failures the API does not model arrive as an error frame instead,
        # with the code and message in the headers and nothing in the payload.
        def stream_error_frame?(message)
          event_header(message.headers, ':message-type') == 'error'
        end

        def decode_error_frame(headers)
          detail = [event_header(headers, ':error-code'), event_header(headers, ':error-message')].compact.join(': ')
          event = { 'type' => 'error' }
          event['error'] = { 'message' => detail } unless detail.empty?
          event
        end

        def stream_exception_type(message)
          headers = message.headers
          return nil unless event_header(headers, ':message-type') == 'exception'

          event_header(headers, ':exception-type') || 'streamingException'
        end

        def event_header(headers, name)
          header = headers[name]
          header.respond_to?(:value) ? header.value : header
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

        def stream_error_event?(event)
          event.keys.any? { |key| key.end_with?('Exception') } || event['type'] == 'error'
        end

        def raise_stream_error(event)
          if event['type'] == 'error'
            message = event.dig('error', 'message') || 'Bedrock streaming error'
            response = ErrorResponse.new({ 'message' => message }, 500)
            Transport::ErrorMiddleware.parse_error(provider: self, response: response)
            return
          end

          key = event.keys.find { |candidate| candidate.end_with?('Exception') }
          message = event[key]['message'] || key
          response = ErrorResponse.new({ 'message' => message }, EXCEPTION_STATUSES.fetch(key, 500))
          Transport::ErrorMiddleware.parse_error(provider: self, response: response)
        end
      end
    end
  end
end
