# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for processing streaming messages from AWS Bedrock.
        module MessageProcessing
          def process_chunk(chunk, &)
            offset = 0
            offset = process_message(chunk, offset, &) while offset < chunk.bytesize
          end

          def process_message(chunk, offset, &)
            return chunk.bytesize unless can_read_prelude?(chunk, offset)

            message_info = extract_message_info(chunk, offset)

            return find_next_message(chunk, offset) unless message_info

            process_valid_message(chunk, offset, message_info, &)
          end

          def process_valid_message(chunk, offset, message_info, &)
            headers = extract_headers(chunk, offset + 12, message_info[:headers_end])
            payload = extract_payload(chunk, message_info[:headers_end], message_info[:payload_end])

            return find_next_message(chunk, offset) unless valid_payload?(payload)

            process_payload_with_headers(payload, headers, &)
            offset + message_info[:total_length]
          end

          private

          def extract_message_info(chunk, offset)
            total_length, headers_length = read_prelude(chunk, offset)
            return unless valid_lengths?(total_length, headers_length)

            message_end = offset + total_length
            return unless chunk.bytesize >= message_end

            headers_end, payload_end = calculate_positions(offset, total_length, headers_length)
            return unless valid_positions?(headers_end, payload_end, chunk.bytesize)

            { total_length:, headers_length:, headers_end:, payload_end: }
          end

          def extract_payload(chunk, headers_end, payload_end)
            chunk[headers_end...payload_end]
          end

          def valid_payload?(payload)
            return false if payload.nil? || payload.empty?

            json_start = payload.index('{')
            json_end = payload.rindex('}')

            !(json_start.nil? || json_end.nil? || json_start >= json_end)
          end

          def extract_headers(chunk, headers_start, headers_end)
            headers_data = chunk[headers_start...headers_end]
            parse_headers(headers_data)
          end

          def parse_headers(headers_data)
            headers = {}
            offset = 0

            while offset < headers_data.bytesize
              break if offset + 4 > headers_data.bytesize

              header_name_length = headers_data[offset...(offset + 1)].unpack1('C')
              offset += 1

              break if offset + header_name_length > headers_data.bytesize

              header_name = headers_data[offset...(offset + header_name_length)]
              offset += header_name_length

              break if offset + 1 > headers_data.bytesize

              header_value_type = headers_data[offset...(offset + 1)].unpack1('C')
              offset += 1

              case header_value_type
              when 0 # BOOL_TRUE
                headers[header_name] = true
              when 1 # BOOL_FALSE
                headers[header_name] = false
              when 2 # BYTE
                break if offset + 1 > headers_data.bytesize

                header_value = headers_data[offset...(offset + 1)].unpack1('C')
                offset += 1

                headers[header_name] = header_value
              when 3 # SHORT (int16, big-endian)
                break if offset + 2 > headers_data.bytesize

                header_value = headers_data[offset...(offset + 2)].unpack1('n')
                offset += 2

                headers[header_name] = header_value
              when 4 # INT (int32, big-endian)
                break if offset + 4 > headers_data.bytesize

                header_value = headers_data[offset...(offset + 4)].unpack1('N')
                offset += 4

                headers[header_name] = header_value
              when 5 # LONG (int64, big-endian)
                break if offset + 8 > headers_data.bytesize

                header_value = headers_data[offset...(offset + 8)].unpack1('Q>')
                offset += 8

                headers[header_name] = header_value
              when 6 # BYTE_ARRAY
                break if offset + 2 > headers_data.bytesize

                header_value_length = headers_data[offset...(offset + 2)].unpack1('n')
                offset += 2

                break if offset + header_value_length > headers_data.bytesize

                header_value = headers_data[offset...(offset + header_value_length)]
                offset += header_value_length

                headers[header_name] = header_value
              when 7 # STRING
                break if offset + 2 > headers_data.bytesize

                header_value_length = headers_data[offset...(offset + 2)].unpack1('n')
                offset += 2

                break if offset + header_value_length > headers_data.bytesize

                header_value = headers_data[offset...(offset + header_value_length)]
                offset += header_value_length

                headers[header_name] = header_value
              when 8 # TIMESTAMP (8-byte milliseconds since epoch)
                break if offset + 8 > headers_data.bytesize

                # Skip timestamp value (8 bytes)
                offset += 8
              when 9 # UUID (16 bytes)
                break if offset + 16 > headers_data.bytesize

                # Skip UUID value (16 bytes)
                offset += 16
              else
                if RubyLLM.config.log_stream_debug
                  RubyLLM.logger.debug "Unknown header value type: #{header_value_type}"
                end
                break
              end
            end

            headers
          end
        end
      end
    end
  end
end
