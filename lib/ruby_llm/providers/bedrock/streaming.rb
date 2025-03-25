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

        def extract_content(data)
          return unless data.is_a?(Hash)

          content_extractors = %i[
            extract_completion_content
            extract_output_text_content
            extract_array_content
            extract_content_block_text
          ]

          content_extractors.each do |extractor|
            content = send(extractor, data)
            return content if content
          end

          nil
        end

        def extract_completion_content(data)
          data['completion'] if data.key?('completion')
        end

        def extract_output_text_content(data)
          data.dig('results', 0, 'outputText')
        end

        def extract_array_content(data)
          return unless data.key?('content')

          if data['content'].is_a?(Array)
            data['content'].map { |item| item['text'] }.join
          else
            data['content']
          end
        end

        def extract_content_block_text(data)
          return unless data.key?('content_block') && data['content_block'].key?('text')

          data['content_block']['text']
        end

        def extract_tool_calls(data)
          data.dig('message', 'tool_calls') || data['tool_calls']
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

          message_info = extract_message_info(chunk, offset)
          return find_next_message(chunk, offset) unless message_info

          process_valid_message(chunk, offset, message_info, &)
        end

        def extract_message_info(chunk, offset)
          total_length, headers_length = read_prelude(chunk, offset)
          return unless valid_lengths?(total_length, headers_length)

          message_end = offset + total_length
          return unless chunk.bytesize >= message_end

          headers_end, payload_end = calculate_positions(offset, total_length, headers_length)
          return unless valid_positions?(headers_end, payload_end, chunk.bytesize)

          { total_length:, headers_length:, headers_end:, payload_end: }
        end

        def process_valid_message(chunk, offset, message_info, &)
          payload = extract_payload(chunk, message_info[:headers_end], message_info[:payload_end])
          return find_next_message(chunk, offset) unless valid_payload?(payload)

          process_payload(payload, &)
          offset + message_info[:total_length]
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
          json_payload = extract_json_payload(payload)
          parse_and_process_json(json_payload, &)
        rescue JSON::ParserError => e
          log_json_parse_error(e, json_payload)
        rescue StandardError => e
          log_general_error(e)
        end

        def extract_json_payload(payload)
          json_start = payload.index('{')
          json_end = payload.rindex('}')
          payload[json_start..json_end]
        end

        def parse_and_process_json(json_payload, &)
          json_data = JSON.parse(json_payload)
          process_json_data(json_data, &)
        end

        def log_json_parse_error(error, json_payload)
          RubyLLM.logger.debug "Failed to parse payload as JSON: #{error.message}"
          RubyLLM.logger.debug "Attempted JSON payload: #{json_payload.inspect}"
        end

        def log_general_error(error)
          RubyLLM.logger.debug "Error processing payload: #{error.message}"
        end

        def process_json_data(json_data, &)
          return unless json_data['bytes']

          data = decode_and_parse_data(json_data)
          create_and_yield_chunk(data, &)
        end

        def decode_and_parse_data(json_data)
          decoded_bytes = Base64.strict_decode64(json_data['bytes'])
          JSON.parse(decoded_bytes)
        end

        def create_and_yield_chunk(data, &block)
          block.call(build_chunk(data))
        end

        def build_chunk(data)
          Chunk.new(
            **extract_chunk_attributes(data)
          )
        end

        def extract_chunk_attributes(data)
          {
            role: :assistant,
            model_id: extract_model_id(data),
            content: extract_streaming_content(data),
            input_tokens: extract_input_tokens(data),
            output_tokens: extract_output_tokens(data),
            tool_calls: extract_tool_calls(data)
          }
        end

        def extract_model_id(data)
          data.dig('message', 'model') || @model_id
        end

        def extract_input_tokens(data)
          data.dig('message', 'usage', 'input_tokens')
        end

        def extract_output_tokens(data)
          data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
        end

        def find_next_prelude(chunk, start_offset)
          scan_range(chunk, start_offset).each do |pos|
            return pos if valid_prelude_at_position?(chunk, pos)
          end
          nil
        end

        def scan_range(chunk, start_offset)
          (start_offset...(chunk.bytesize - 8))
        end

        def valid_prelude_at_position?(chunk, pos)
          lengths = extract_potential_lengths(chunk, pos)
          valid_prelude_lengths?(*lengths)
        end

        def extract_potential_lengths(chunk, pos)
          [
            chunk[pos...pos + 4].unpack1('N'),
            chunk[pos + 4...pos + 8].unpack1('N')
          ]
        end

        def valid_prelude_lengths?(total_length, headers_length)
          return false unless total_length && headers_length
          return false unless total_length.positive? && headers_length.positive?
          return false unless total_length < 1_000_000
          return false unless headers_length < total_length

          true
        end
      end
    end
  end
end
