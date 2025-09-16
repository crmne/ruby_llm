# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Helpers for parsing AWS Event Stream prelude in Bedrock streaming.
        module Prelude
          PRELUDE_BYTES = 12
          CRC_BYTES = 4
          MAX_MESSAGE_BYTES = 1_000_000

          # Returns true if enough bytes remain to read a full prelude
          # (total_length + headers_length + headers_crc)
          def can_read_prelude?(chunk, offset)
            chunk.bytesize - offset >= PRELUDE_BYTES
          end

          # Reads the 8-byte length fields from the prelude at +offset+
          # and returns [total_length, headers_length].
          def read_prelude(chunk, offset)
            total_length = chunk[offset...(offset + 4)].unpack1('N')
            headers_length = chunk[(offset + 4)...(offset + 8)].unpack1('N')
            [total_length, headers_length]
          end

          # Validates the relationship between total and headers lengths
          def valid_lengths?(total_length, headers_length)
            valid_length_constraints?(total_length, headers_length)
          end

          # Computes end offsets of headers and payload (exclusive)
          def calculate_positions(offset, total_length, headers_length)
            headers_end = offset + PRELUDE_BYTES + headers_length
            payload_end = offset + total_length - CRC_BYTES
            [headers_end, payload_end]
          end

          # Ensures derived positions are within the chunk bounds and ordered
          def valid_positions?(headers_end, payload_end, chunk_size)
            headers_end < payload_end && headers_end < chunk_size && payload_end <= chunk_size
          end

          # Attempts to find the next plausible prelude start after a parse error.
          # Returns the next offset to continue scanning from.
          def find_next_message(chunk, offset)
            next_prelude = find_next_prelude(chunk, offset + 4)
            next_prelude || chunk.bytesize
          end

          def find_next_prelude(chunk, start_offset)
            scan_range(chunk, start_offset).each do |pos|
              return pos if valid_prelude_at_position?(chunk, pos)
            end
            nil
          end

          private

          def scan_range(chunk, start_offset)
            (start_offset...(chunk.bytesize - 8))
          end

          def valid_prelude_at_position?(chunk, pos)
            lengths = extract_potential_lengths(chunk, pos)
            valid_length_constraints?(*lengths)
          end

          def extract_potential_lengths(chunk, pos)
            [
              chunk[pos...(pos + 4)].unpack1('N'),
              chunk[(pos + 4)...(pos + 8)].unpack1('N')
            ]
          end

          def valid_length_constraints?(total_length, headers_length)
            return false if total_length.nil? || headers_length.nil?
            return false if total_length <= 0 || total_length > MAX_MESSAGE_BYTES
            return false if headers_length <= 0 || headers_length >= total_length

            true
          end
        end
      end
    end
  end
end
