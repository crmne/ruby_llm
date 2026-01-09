# frozen_string_literal: true

module RubyLLM
  # Handles streaming responses from AI providers.
  module Streaming
    module_function

    def stream_response(connection, payload, additional_headers = {}, &block)
      accumulator = StreamAccumulator.new

      response = connection.post stream_url, payload do |req|
        req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
        if faraday_1?
          req.options[:on_data] = handle_stream do |chunk|
            accumulator.add chunk
            block.call chunk
          end
        else
          req.options.on_data = handle_stream do |chunk|
            accumulator.add chunk
            block.call chunk
          end
        end
      end

      message = accumulator.to_message(response)
      RubyLLM.logger.debug "Stream completed: #{message.content}"
      message
    end

    def handle_stream(&block)
      to_json_stream do |data|
        block.call(build_chunk(data)) if data
      end
    end

    private

    def faraday_1?
      Faraday::VERSION.start_with?('1')
    end

    def to_json_stream(&)
      buffer = +''
      parser = EventStreamParser::Parser.new

      create_stream_processor(parser, buffer, &)
    end

    def create_stream_processor(parser, buffer, &)
      if faraday_1?
        legacy_stream_processor(parser, &)
      else
        stream_processor(parser, buffer, &)
      end
    end

    def process_stream_chunk(chunk, parser, env, &)
      RubyLLM.logger.debug "Received chunk: #{chunk}" if RubyLLM.config.log_stream_debug

      if error_chunk?(chunk)
        handle_error_chunk(chunk, env)
      elsif json_error_payload?(chunk)
        handle_json_error_chunk(chunk, env)
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

    def json_error_payload?(chunk)
      chunk.lstrip.start_with?('{') && chunk.include?('"error"')
    end

    def handle_json_error_chunk(chunk, env)
      parsed_data = JSON.parse(chunk)
      status, _message = parse_streaming_error(parsed_data.to_json)
      error_response = build_stream_error_response(parsed_data, env, status)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse JSON error chunk: #{e.message}"
    end

    def handle_error_chunk(chunk, env)
      error_data = chunk.split("\n")[1].delete_prefix('data: ')
      parsed_data = JSON.parse(error_data)
      status, _message = parse_streaming_error(parsed_data.to_json)
      error_response = build_stream_error_response(parsed_data, env, status)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse error chunk: #{e.message}"
    end

    def handle_failed_response(chunk, buffer, env)
      buffer << chunk
      error_data = JSON.parse(buffer)
      status, _message = parse_streaming_error(error_data.to_json)
      error_response = env.merge(body: error_data, status: status || env.status)
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
          yield handle_data(data, env, &block) unless data == '[DONE]'
        end
      end
    end

    def handle_data(data, env)
      parsed = JSON.parse(data)
      return parsed unless parsed.is_a?(Hash) && parsed.key?('error')

      status, _message = parse_streaming_error(parsed.to_json)
      error_response = build_stream_error_response(parsed, env, status)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse data chunk: #{e.message}"
    end

    def handle_error_event(data, env)
      parsed_data = JSON.parse(data)
      status, _message = parse_streaming_error(parsed_data.to_json)
      error_response = build_stream_error_response(parsed_data, env, status)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse error event: #{e.message}"
    end

    def parse_streaming_error(data)
      error_data = JSON.parse(data)
      [500, error_data['message'] || 'Unknown streaming error']
    rescue JSON::ParserError => e
      RubyLLM.logger.debug "Failed to parse streaming error: #{e.message}"
      [500, "Failed to parse error: #{data}"]
    end

    def build_stream_error_response(parsed_data, env, status)
      error_status = status || env&.status || 500

      if faraday_1?
        Struct.new(:body, :status).new(parsed_data, error_status)
      else
        env.merge(body: parsed_data, status: error_status)
      end
    end
  end
end
