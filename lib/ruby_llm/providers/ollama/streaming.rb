# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Streaming methods for the Ollama API implementation
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def handle_stream(&block)
          to_json_stream do |data|
            # FIXME: on connection close, on_data is called with the entire response so far as one chunk
            # consisting of an Array of unparsed JSON strings (ie. an array of lines).
            #
            # It is detected and skipped here, but this is a code smell;
            # likely standard SSE behavior which shouldn't be happening for NDJSON streaming.
            done = data.is_a?(Array) && data.first.is_a?(String) && data.first[0] == '{'

            block.call(build_chunk(data)) if data && !done
          end
        end

        def build_chunk(data)
          data = Tools.preprocess_tool_calls(data)

          Chunk.new(
            role: :assistant,
            content: data.dig('message', 'content'),
            model_id: data['model'],
            tool_calls: parse_tool_calls(data.dig('message', 'tool_calls')),

            # NOTE: unavailable in the response - https://ollama.readthedocs.io/en/api/#streaming-responses
            input_tokens: nil,
            output_tokens: nil
          )
        end

        def handle_sse(chunk, _parser, env, &block)
          # NOTE: Ollama uses NDJSON rather than standard SSE here
          content_type = env.response_headers['content-type']
          unless content_type =~ %r{application/x-ndjson}
            raise "Unexpected content-type when parsing Ollama streaming response: #{content_type}"
          end

          chunk.split(/\n+/).each do |line|
            next if line.empty?

            parsed_data = JSON.parse(line)
            block.call(parsed_data)
          end
        end
      end
    end
  end
end
