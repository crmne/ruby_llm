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
            # FIXME: for some reason, there's an unexpected final call
            # from on_data with the complete response as an Array.
            #
            # It is skipped here, but this smells a bit; this method shouldn't
            # need to be overridden just for this. Will look into it
            done = data.is_a?(Array) || data['done']

            block.call(build_chunk(data)) if data && !done
          end
        end

        def build_chunk(data)
          Chunk.new(
            role: :assistant,
            content: data.dig('message', 'content'),
            model_id: data['model'],

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
