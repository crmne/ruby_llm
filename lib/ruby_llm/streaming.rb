# frozen_string_literal: true

require 'event_stream_parser'
require 'faraday'
require 'json'

module RubyLLM
  module Streaming # :nodoc: all
    StreamState = Struct.new(:parser, :buffer) do
      def initialize
        super(EventStreamParser::Parser.new, +'')
      end
    end

    module_function

    def stream_response(payload, additional_headers = {}, &block)
      accumulator = StreamAccumulator.new

      response = stream_events(stream_url, payload, additional_headers) do |data|
        chunk = build_chunk(data)
        accumulator.add chunk
        block.call chunk
      end

      message = accumulator.to_message(response)
      RubyLLM.logger.debug { "Stream completed: #{message.content}" }
      message
    end

    # Posts +payload+ to +url+ as a server-sent event stream, yielding each
    # parsed event Hash. Returns the Faraday response.
    def stream_events(url, payload, additional_headers = {}, &block)
      on_data = build_on_data_handler do |data|
        block.call(data) if data.is_a?(Hash)
      end

      @connection.post url, payload, usage: @usage_tracker do |req|
        req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
        if faraday_1?
          req.options[:on_data] = on_data
        else
          req.options.on_data = on_data
        end
      end
    end

    def handle_stream(&block)
      build_on_data_handler do |data|
        block.call(build_chunk(data)) if data.is_a?(Hash)
      end
    end

    private

    def faraday_1?
      Faraday::VERSION.start_with?('1')
    end

    # Parser state lives on the env so every retry attempt starts fresh;
    # ErrorMiddleware clears it per attempt. Faraday v1 passes no env to
    # on_data, so it falls back to one state for the whole request.
    def build_on_data_handler(&handler)
      fallback_state = StreamState.new

      FaradayHandlers.build(
        faraday_v1: faraday_1?,
        on_chunk: ->(chunk, env) { process_stream_chunk(chunk, stream_state(env, fallback_state), env, &handler) },
        on_failed_response: lambda { |chunk, env|
          handle_failed_response(chunk, stream_state(env, fallback_state).buffer, env)
        }
      )
    end

    def stream_state(env, fallback_state)
      return fallback_state unless env.respond_to?(:[]=)

      env[:streaming_state] ||= StreamState.new
    end

    def process_stream_chunk(chunk, state, env, &)
      RubyLLM.logger.debug { "Received chunk: #{chunk}" } if RubyLLM.config.log_stream_debug

      if error_chunk?(chunk)
        handle_error_chunk(chunk, env)
      elsif json_error_payload?(chunk)
        handle_json_error_chunk(chunk, env)
      else
        handle_sse(chunk, state.parser, env, &)
      end
    end

    def error_chunk?(chunk)
      chunk.start_with?('event: error')
    end

    def json_error_payload?(chunk)
      chunk.lstrip.start_with?('{') && chunk.include?('"error"')
    end

    def handle_json_error_chunk(chunk, env)
      parse_error_from_json(chunk, env, 'Failed to parse JSON error chunk')
    end

    def handle_error_chunk(chunk, env)
      error_data = chunk.split("\n")[1]&.delete_prefix('data: ')
      parse_error_from_json(error_data, env, 'Failed to parse error chunk') if error_data
    end

    def handle_failed_response(chunk, buffer, env)
      buffer << chunk
      error_data = JSON.parse(buffer)
      raise_stream_error(buffer, error_data, env)
    rescue JSON::ParserError
      RubyLLM.logger.debug { "Accumulating error chunk: #{chunk}" }
    end

    # Marking the env once events flow lets the retry middleware know this
    # stream already delivered chunks, so a mid-stream failure must not be
    # retried into the same accumulator and user block.
    def handle_sse(chunk, parser, env)
      parser.feed(chunk) do |type, data|
        case type.to_sym
        when :error
          handle_error_event(data, env)
        else
          next if data == '[DONE]'

          env[:streaming_started] = true if env.respond_to?(:[]=)
          yield handle_data(data, env)
        end
      end
    end

    def handle_data(data, env)
      parsed = JSON.parse(data)
      return parsed unless parsed.is_a?(Hash) && parsed.key?('error')

      raise_stream_error(data, parsed, env)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug { "Failed to parse data chunk: #{e.message}" }
    end

    def handle_error_event(data, env)
      parse_error_from_json(data, env, 'Failed to parse error event')
    end

    def parse_streaming_error(data)
      error_data = JSON.parse(data)
      message = error_data.is_a?(Hash) ? error_data['message'] : error_data.to_s
      [500, message || 'Unknown streaming error']
    rescue JSON::ParserError => e
      RubyLLM.logger.debug { "Failed to parse streaming error: #{e.message}" }
      [500, "Failed to parse error: #{data}"]
    end

    def raise_stream_error(raw_data, parsed_data, env)
      status, _message = parse_streaming_error(raw_data)
      error_response = build_stream_error_response(parsed_data, env, status)
      env[:streaming_error_response] = error_response if env.respond_to?(:[]=)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    end

    def parse_error_from_json(data, env, error_message)
      parsed_data = JSON.parse(data)
      raise_stream_error(data, parsed_data, env)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug { "#{error_message}: #{e.message}" }
    end

    def build_stream_error_response(parsed_data, env, status)
      error_status = failed_http_status(env) || status || 500

      if faraday_1?
        Struct.new(:body, :status).new(parsed_data, error_status)
      else
        env.merge(body: parsed_data, status: error_status)
      end
    end

    def failed_http_status(env)
      status = env&.status
      return status if status&.>= 400

      nil
    end

    module FaradayHandlers # :nodoc:
      module_function

      def build(faraday_v1:, on_chunk:, on_failed_response:)
        if faraday_v1
          v1_on_data(on_chunk)
        else
          v2_on_data(on_chunk, on_failed_response)
        end
      end

      def v1_on_data(on_chunk)
        proc do |chunk, _size|
          on_chunk.call(chunk, nil)
        end
      end

      def v2_on_data(on_chunk, on_failed_response)
        proc do |chunk, _bytes, env|
          # Some adapters do not expose response status during on_data.
          status = env&.status

          if status && status != 200
            on_failed_response.call(chunk, env)
          else
            on_chunk.call(chunk, env)
          end
        end
      end
    end
  end
end
