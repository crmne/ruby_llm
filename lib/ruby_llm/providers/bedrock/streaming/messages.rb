# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Message parsing helpers for AWS Bedrock streaming.
        module Messages
          # Reference constant from Prelude for clarity and consistency
          PRELUDE_BYTES = RubyLLM::Providers::Bedrock::Streaming::Prelude::PRELUDE_BYTES

          # Header value type identifiers for AWS event stream
          HEADER_TYPE_BOOL_TRUE   = 0
          HEADER_TYPE_BOOL_FALSE  = 1
          HEADER_TYPE_BYTE        = 2
          HEADER_TYPE_SHORT       = 3
          HEADER_TYPE_INT         = 4
          HEADER_TYPE_LONG        = 5
          HEADER_TYPE_BYTE_ARRAY  = 6
          HEADER_TYPE_STRING      = 7
          HEADER_TYPE_TIMESTAMP   = 8
          HEADER_TYPE_UUID        = 9

          HEADER_VALUE_PARSERS = {
            HEADER_TYPE_BOOL_TRUE => ->(_ctx, _data, offset) { [true, offset, true] },
            HEADER_TYPE_BOOL_FALSE => ->(_ctx, _data, offset) { [false, offset, true] },
            HEADER_TYPE_BYTE => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 1)

              [data.getbyte(offset), offset + 1, true]
            end,
            HEADER_TYPE_SHORT => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 2)

              [data[offset...(offset + 2)].unpack1('n'), offset + 2, true]
            end,
            HEADER_TYPE_INT => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 4)

              [data[offset...(offset + 4)].unpack1('N'), offset + 4, true]
            end,
            HEADER_TYPE_LONG => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 8)

              [data[offset...(offset + 8)].unpack1('Q>'), offset + 8, true]
            end,
            HEADER_TYPE_BYTE_ARRAY => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 2)

              value_length = data[offset...(offset + 2)].unpack1('n')
              offset += 2
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, value_length)

              [data[offset...(offset + value_length)], offset + value_length, true]
            end,
            HEADER_TYPE_STRING => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 2)

              value_length = data[offset...(offset + 2)].unpack1('n')
              offset += 2
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, value_length)

              [data[offset...(offset + value_length)], offset + value_length, true]
            end,
            HEADER_TYPE_TIMESTAMP => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 8)

              [nil, offset + 8, false]
            end,
            HEADER_TYPE_UUID => lambda do |ctx, data, offset|
              return [nil, nil, false] unless ctx.bytes_available?(data, offset, 16)

              [nil, offset + 16, false]
            end
          }.freeze

          # Process all messages in a given chunk, invoking the provided block
          # for each parsed payload.
          #
          # @param chunk [String] binary event stream chunk
          # @yield [payload, headers] yields payload and headers for each message
          # @return [void]
          def process_chunk(chunk, &)
            offset = 0
            offset = process_message(chunk, offset, &) while offset < chunk.bytesize
          end

          # Process a single message starting at the provided offset.
          # Returns the next offset to continue reading.
          #
          # @param chunk [String]
          # @param offset [Integer]
          # @yield [payload, headers]
          # @return [Integer] next offset position
          def process_message(chunk, offset, &)
            return chunk.bytesize unless can_read_prelude?(chunk, offset)

            message_info = extract_message_info(chunk, offset)

            return find_next_message(chunk, offset) unless message_info

            process_valid_message(chunk, offset, message_info, &)
          end

          # Process a message with known-good prelude and structure.
          #
          # @param chunk [String]
          # @param offset [Integer]
          # @param message_info [Hash]
          # @yield [payload, headers]
          # @return [Integer] next offset position
          def process_valid_message(chunk, offset, message_info, &)
            headers = extract_headers(chunk, offset + PRELUDE_BYTES, message_info[:headers_end])
            payload = extract_payload(chunk, message_info[:headers_end], message_info[:payload_end])

            return find_next_message(chunk, offset) unless valid_payload?(payload)

            process_payload_with_headers(payload, headers, &)
            offset + message_info[:total_length]
          end

          private

          # Extracts message structure information from the chunk at offset.
          # Returns a Hash containing total_length, headers_length, headers_end, payload_end
          # or nil if invalid.
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
            parse_event_stream_headers(headers_data)
          end

          def parse_event_stream_headers(headers_data)
            headers = {}
            offset = 0

            while offset < headers_data.bytesize
              header_name, header_value, new_offset = extract_header(headers_data, offset)
              break unless new_offset

              offset = new_offset
              headers[header_name] = header_value if header_name
            end

            headers
          end

          # Extract a single header starting at offset. Returns [name, value, new_offset],
          # where name may be nil if the header should not be added (e.g., skipped types).
          def extract_header(data, offset)
            return [nil, nil, nil] unless bytes_available?(data, offset, 1)

            name_length = data.getbyte(offset)
            offset += 1

            return [nil, nil, nil] unless bytes_available?(data, offset, name_length)

            name = data[offset...(offset + name_length)]
            offset += name_length

            return [nil, nil, nil] unless bytes_available?(data, offset, 1)

            value_type = data.getbyte(offset)
            offset += 1

            value, new_offset, add = parse_header_value(data, offset, value_type)
            return [nil, nil, nil] unless new_offset

            [add ? name : nil, value, new_offset]
          end

          # Parse a header value given its type. Returns [value, new_offset, add_to_headers]
          def parse_header_value(data, offset, value_type)
            handler = HEADER_VALUE_PARSERS[value_type]
            return handler.call(self, data, offset) if handler

            log_unknown_header_type(value_type)
            [nil, nil, false]
          end

          # @param data [String]
          # @param offset [Integer]
          # @param length [Integer]
          # @return [Boolean]
          def bytes_available?(data, offset, length)
            offset + length <= data.bytesize
          end

          public :bytes_available?

          def log_unknown_header_type(header_value_type)
            return unless RubyLLM.config.log_stream_debug

            RubyLLM.logger.debug "Unknown header value type: #{header_value_type}"
          end
        end
      end
    end
  end
end
