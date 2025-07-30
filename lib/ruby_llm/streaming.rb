# frozen_string_literal: true

module RubyLLM
  # Handles streaming responses from AI providers. Provides a unified way to process
  # chunked responses, accumulate content, and handle provider-specific streaming formats.
  # Each provider implements provider-specific parsing while sharing common stream handling
  # patterns.
  module Streaming
    module_function

    def stream_response(connection, payload, &block)
      accumulator = StreamAccumulator.new

      response = connection.post stream_url, payload do |req|
        if req.options.respond_to?(:on_data)
          # Handle Faraday 2.x streaming with on_data method
          req.options.on_data = handle_stream do |chunk|
            accumulator.add chunk
            block.call chunk
          end
        else
          # Handle Faraday 1.x streaming with :on_data key
          req.options[:on_data] = handle_stream do |chunk|
            accumulator.add chunk
            block.call chunk
          end
        end
      end

      accumulator.to_message(response)
    end

    def handle_stream(&block)
      to_json_stream do |data|
        block.call(build_chunk(data)) if data
      end
    end

    private

    def to_json_stream(&)
      buffer = String.new
      parser = EventStreamParser::Parser.new

      create_stream_processor(parser, buffer, &)
    end

    def create_stream_processor(parser, buffer, &)
      if Faraday::VERSION.start_with?('1')
        # Faraday 1.x: on_data receives (chunk, size)
        legacy_stream_processor(parser, &)
      else
        # Faraday 2.x: on_data receives (chunk, bytes, env)
        stream_processor(parser, buffer, &)
      end
    end

    def process_stream_chunk(chunk, parser, env, &)
      RubyLLM.logger.debug "Received chunk: #{chunk}"

      if error_chunk?(chunk)
        handle_error_chunk(chunk, env)
      else
        yield handle_sse(chunk, parser, env, &)
      end
    end

    def legacy_stream_processor(parser, &block)
      proc do |chunk, _size|
        process_stream_chunk(chunk, parser, nil, &block)
      end
    end

    def stream_processor(parser, buffer, &block)
      proc do |chunk, _bytes, env|
        if env&.status == 200
          process_stream_chunk(chunk, parser, env, &block)
        else
          handle_failed_response(chunk, buffer, env)
        end
      end
    end

    def error_chunk?(chunk)
      chunk.start_with?('event: error')
    end

    def handle_error_chunk(chunk, env)
      error_data = chunk.split("\n")[1].delete_prefix('data: ')
      status, _message = parse_streaming_error(error_data)
      parsed_data = JSON.parse(error_data)

      # Create a response-like object that works for both Faraday v1 and v2
      error_response = if env
                         env.merge(body: parsed_data, status: status)
                       else
                         # For Faraday v1, create a simple object that responds to .status and .body
                         Struct.new(:body, :status).new(parsed_data, status)
                       end

      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse error chunk: #{e.message}"
    end

    def handle_failed_response(chunk, buffer, env)
      buffer << chunk
      error_data = JSON.parse(buffer)
      error_response = env.merge(body: error_data)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError
      RubyLLM.logger.debug "Accumulating error chunk: #{chunk}"
    end

    def handle_sse(chunk, parser, env, &block)
      parser.feed(chunk) do |type, data|
        case type.to_sym
        when :error
          handle_error_event(data, env)
        else
          yield handle_data(data, &block) unless data == '[DONE]'
        end
      end
    end

    def handle_data(data)
      JSON.parse(data)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse data chunk: #{e.message}"
    end

    def handle_error_event(data, env)
      status, _message = parse_streaming_error(data)
      parsed_data = JSON.parse(data)

      # Create a response-like object that works for both Faraday v1 and v2
      error_response = if env
                         env.merge(body: parsed_data, status: status)
                       else
                         # For Faraday v1, create a simple object that responds to .status and .body
                         Struct.new(:body, :status).new(parsed_data, status)
                       end

      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse error event: #{e.message}"
    end
  end
end
