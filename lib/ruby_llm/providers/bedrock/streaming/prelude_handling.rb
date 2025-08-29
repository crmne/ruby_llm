# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for handling message preludes in AWS Bedrock streaming responses.
        module PreludeHandling
          def can_read_prelude?(chunk, offset)
            can_read = chunk.bytesize - offset >= 12
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Can read prelude: #{can_read} (chunk_size=#{chunk.bytesize}, offset=#{offset})"
            end
            can_read
          end

          def read_prelude(chunk, offset)
            total_length = chunk[offset...(offset + 4)].unpack1('N')
            headers_length = chunk[(offset + 4)...(offset + 8)].unpack1('N')
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Read prelude: total_length=#{total_length}, headers_length=#{headers_length}"
            end
            [total_length, headers_length]
          end

          def valid_lengths?(total_length, headers_length)
            valid = valid_length_constraints?(total_length, headers_length)
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Valid lengths: #{valid} (total_length=#{total_length}, headers_length=#{headers_length})"
            end
            valid
          end

          def calculate_positions(offset, total_length, headers_length)
            headers_end = offset + 12 + headers_length
            payload_end = offset + total_length - 4 # Subtract 4 bytes for message CRC
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Calculated positions: headers_end=#{headers_end}, payload_end=#{payload_end}"
            end
            [headers_end, payload_end]
          end

          def valid_positions?(headers_end, payload_end, chunk_size)
            valid = headers_end < payload_end && headers_end < chunk_size && payload_end <= chunk_size
            if RubyLLM.config.log_stream_debug
              RubyLLM.logger.debug "Valid positions: #{valid} (headers_end=#{headers_end}, payload_end=#{payload_end}, chunk_size=#{chunk_size})"
            end
            valid
          end

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
            return false if total_length <= 0 || total_length > 1_000_000
            return false if headers_length <= 0 || headers_length >= total_length

            true
          end
        end
      end
    end
  end
end
