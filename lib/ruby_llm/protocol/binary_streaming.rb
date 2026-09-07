# frozen_string_literal: true

module RubyLLM
  class Protocol
    module BinaryStreaming # :nodoc: all
      def stream_binary(url, payload, &)
        progress = {}
        fallback = Streaming::StreamState.new
        on_data = binary_on_data(fallback, progress, &)

        response = @connection.post(url, payload, usage: @usage_tracker) do |request|
          (request.options.context ||= {})[Transport::Connection::STREAM_PROGRESS_KEY] = progress
          if faraday_1?
            request.options[:on_data] = on_data
          else
            request.options.on_data = on_data
          end
        end
        state = response.env[:streaming_state] || fallback
        validate_binary_response(response, state.buffer)
        yield state.buffer.dup unless progress[:started] || state.buffer.empty?
        response.env.body = state.buffer.b
        response
      end

      private

      def binary_on_data(fallback, progress)
        lambda do |chunk, bytes, env = nil|
          next if chunk.empty?

          state = stream_state(env, fallback)
          state.buffer.clear if env.nil? && bytes && bytes <= state.buffer.bytesize
          if failed_http_status(env)
            handle_failed_response(chunk, state.buffer, env)
          else
            state.buffer << chunk.b
            next unless binary_response?(env)

            progress[:started] = true
            yield chunk.b
          end
        end
      end

      def binary_response?(env)
        return false unless env&.status&.between?(200, 299)

        content_type = env.response_headers&.fetch('content-type', '').to_s.split(';').first
        content_type&.start_with?('audio/') || content_type == 'application/octet-stream'
      end

      def validate_binary_response(response, data)
        return if binary_response?(response.env)

        begin
          raise_stream_error(data, JSON.parse(data), response.env)
        rescue JSON::ParserError
          nil
        end
        raise Error.new('Expected an audio response from the speech endpoint', response: response)
      end
    end
  end
end
