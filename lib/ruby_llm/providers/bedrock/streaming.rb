# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Providers
    module Bedrock
      # Streaming methods for the AWS Bedrock API implementation
      module Streaming
        module_function

        def stream_url
          "model/#{@model_id}/invoke-with-response-stream"
        end

        def handle_stream(&block)
          proc do |chunk, _bytes, env|
            if env && env.status != 200
              handle_error_response(chunk, env)
            else
              process_chunk(chunk, &block)
            end
          end
        end

        def json_delta?(data)
          data['type'] == 'content_block_delta' && data.dig('delta', 'type') == 'input_json_delta'
        end

        def extract_streaming_content(data)
          if data.is_a?(Hash)
            case data['type']
            when 'content_block_start'
              # Initial content block, might have some text
              data.dig('content_block', 'text').to_s
            when 'content_block_delta'
              # Incremental content updates
              data.dig('delta', 'text').to_s
            else
              ''
            end
          else
            ''
          end
        end

        private

        def handle_error_response(chunk, env)
          buffer = String.new
          buffer << chunk
          begin
            error_data = JSON.parse(buffer)
            error_response = env.merge(body: error_data)
            ErrorMiddleware.parse_error(provider: self, response: error_response)
          rescue JSON::ParserError
            # Keep accumulating if we don't have complete JSON yet
            RubyLLM.logger.debug "Accumulating error chunk: #{chunk}"
          end
        end

        def process_chunk(chunk, &)
          offset = 0
          offset = process_message(chunk, offset, &) while offset < chunk.bytesize
        rescue StandardError => e
          RubyLLM.logger.debug "Error processing chunk: #{e.message}"
          RubyLLM.logger.debug "Chunk size: #{chunk.bytesize}"
        end

        def process_message(chunk, offset, &)
          return chunk.bytesize unless can_read_prelude?(chunk, offset)

          total_length, headers_length = read_prelude(chunk, offset)
          return find_next_message(chunk, offset) unless valid_lengths?(total_length, headers_length)

          message_end = offset + total_length
          return chunk.bytesize if chunk.bytesize < message_end

          headers_end, payload_end = calculate_positions(offset, total_length, headers_length)
          return find_next_message(chunk, offset) unless valid_positions?(headers_end, payload_end, chunk.bytesize)

          payload = extract_payload(chunk, headers_end, payload_end)
          return message_end unless valid_payload?(payload)

          process_payload(payload, &)
          message_end
        end

        def can_read_prelude?(chunk, offset)
          chunk.bytesize - offset >= 12
        end

        def read_prelude(chunk, offset)
          total_length = chunk[offset...offset + 4].unpack1('N')
          headers_length = chunk[offset + 4...offset + 8].unpack1('N')
          [total_length, headers_length]
        end

        def valid_lengths?(total_length, headers_length)
          return false if total_length.nil? || headers_length.nil?
          return false if total_length <= 0 || total_length > 1_000_000
          return false if headers_length <= 0 || headers_length > total_length

          true
        end

        def calculate_positions(offset, total_length, headers_length)
          headers_end = offset + 12 + headers_length
          payload_end = offset + total_length - 4 # Subtract 4 bytes for message CRC
          [headers_end, payload_end]
        end

        def valid_positions?(headers_end, payload_end, chunk_size)
          return false if headers_end >= payload_end
          return false if headers_end >= chunk_size
          return false if payload_end > chunk_size

          true
        end

        def find_next_message(chunk, offset)
          next_prelude = find_next_prelude(chunk, offset + 4)
          next_prelude || chunk.bytesize
        end

        def extract_payload(chunk, headers_end, payload_end)
          chunk[headers_end...payload_end]
        end

        def valid_payload?(payload)
          return false if payload.nil? || payload.empty?

          json_start = payload.index('{')
          json_end = payload.rindex('}')

          return false if json_start.nil? || json_end.nil? || json_start >= json_end

          true
        end

        def process_payload(payload, &)
          json_start = payload.index('{')
          json_end = payload.rindex('}')
          json_payload = payload[json_start..json_end]

          begin
            json_data = JSON.parse(json_payload)
            process_json_data(json_data, &)
          rescue JSON::ParserError => e
            RubyLLM.logger.debug "Failed to parse payload as JSON: #{e.message}"
            RubyLLM.logger.debug "Attempted JSON payload: #{json_payload.inspect}"
          rescue StandardError => e
            RubyLLM.logger.debug "Error processing payload: #{e.message}"
          end
        end

        def process_json_data(json_data, &block)
          return unless json_data['bytes']

          decoded_bytes = Base64.strict_decode64(json_data['bytes'])
          data = JSON.parse(decoded_bytes)

          block.call(
            Chunk.new(
              role: :assistant,
              model_id: data.dig('message', 'model') || @model_id,
              content: extract_streaming_content(data),
              input_tokens: extract_input_tokens(data),
              output_tokens: extract_output_tokens(data),
              tool_calls: extract_tool_calls(data)
            )
          )
        end

        def extract_input_tokens(data)
          data.dig('message', 'usage', 'input_tokens')
        end

        def extract_output_tokens(data)
          data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
        end

        def extract_content(data)
          case data
          when Hash
            if data.key?('completion')
              data['completion']
            elsif data.dig('results', 0, 'outputText')
              data.dig('results', 0, 'outputText')
            elsif data.key?('content')
              data['content'].is_a?(Array) ? data['content'].map { |item| item['text'] }.join : data['content']
            elsif data.key?('content_block') && data['content_block'].key?('text')
              # Handle the newly decoded JSON structure
              data['content_block']['text']
            end
          end
        end

        def extract_tool_calls(data)
          data.dig('message', 'tool_calls') || data['tool_calls']
        end

        def find_next_prelude(chunk, start_offset)
          # Look for potential message prelude by scanning for reasonable length values
          (start_offset...(chunk.bytesize - 8)).each do |pos|
            potential_total_length = chunk[pos...pos + 4].unpack1('N')
            potential_headers_length = chunk[pos + 4...pos + 8].unpack1('N')

            # Check if these look like valid lengths
            if potential_total_length && potential_headers_length &&
               potential_total_length.positive? && potential_total_length < 1_000_000 &&
               potential_headers_length.positive? && potential_headers_length < potential_total_length
              return pos
            end
          end
          nil
        end
      end
    end
  end
end
