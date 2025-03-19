# frozen_string_literal: true

require 'stringio'
require 'tempfile'
require 'zlib'

module RubyLLM
  module Providers
    module Bedrock
      # Decoder for AWS EventStream format used by Bedrock streaming responses
      class Decoder
        include Enumerable

        ONE_MEGABYTE = 1024 * 1024
        private_constant :ONE_MEGABYTE

        # bytes of prelude part, including 4 bytes of
        # total message length, headers length and crc checksum of prelude
        PRELUDE_LENGTH = 12
        private_constant :PRELUDE_LENGTH

        # 4 bytes message crc checksum
        CRC32_LENGTH = 4
        private_constant :CRC32_LENGTH

        # @param [Hash] options The initialization options.
        # @option options [Boolean] :format (true) When `false` it
        #   disables user-friendly formatting for message header values
        #   including timestamp and uuid etc.
        def initialize(options = {})
          @format = options.fetch(:format, true)
          @message_buffer = ''
        end

        # Decodes messages from a binary stream
        #
        # @param [IO#read] io An IO-like object
        #   that responds to `#read`
        #
        # @yieldparam [Message] message
        # @return [Enumerable<Message>, nil] Returns a new Enumerable
        #   containing decoded messages if no block is given
        def decode(io, &block)
          raw_message = io.read
          decoded_message = decode_message(raw_message)
          return wrap_as_enumerator(decoded_message) unless block_given?
          # fetch message only
          raw_event, _eof = decoded_message
          block.call(raw_event)
        end

        # Decodes a single message from a chunk of string
        #
        # @param [String] chunk A chunk of string to be decoded,
        #   chunk can contain partial event message to multiple event messages
        #   When not provided, decode data from #message_buffer
        #
        # @return [Array<Message|nil, Boolean>] Returns single decoded message
        #   and boolean pair, the boolean flag indicates whether this chunk
        #   has been fully consumed, unused data is tracked at #message_buffer
        def decode_chunk(chunk = nil)
          @message_buffer = [@message_buffer, chunk].pack('a*a*') if chunk
          decode_message(@message_buffer)
        end

        private

        # exposed via object.send for testing
        attr_reader :message_buffer

        def wrap_as_enumerator(decoded_message)
          Enumerator.new do |yielder|
            yielder << decoded_message
          end
        end

        def decode_message(raw_message)
          # incomplete message prelude received
          return [nil, true] if raw_message.bytesize < PRELUDE_LENGTH

          prelude, content = raw_message.unpack("a#{PRELUDE_LENGTH}a*")

          # decode prelude
          total_length, header_length = decode_prelude(prelude)

          # incomplete message received, leave it in the buffer
          return [nil, true] if raw_message.bytesize < total_length

          content, checksum, remaining = content.unpack("a#{total_length - PRELUDE_LENGTH - CRC32_LENGTH}Na*")
          unless Zlib.crc32([prelude, content].pack('a*a*')) == checksum
            raise Error, "Message checksum error"
          end

          # decode headers and payload
          headers, payload = decode_context(content, header_length)

          @message_buffer = remaining

          [Message.new(headers: headers, payload: payload), remaining.empty?]
        end

        def decode_prelude(prelude)
          # prelude contains length of message and headers,
          # followed with CRC checksum of itself
          content, checksum = prelude.unpack("a#{PRELUDE_LENGTH - CRC32_LENGTH}N")
          raise Error, "Prelude checksum error" unless Zlib.crc32(content) == checksum
          content.unpack('N*')
        end

        def decode_context(content, header_length)
          encoded_header, encoded_payload = content.unpack("a#{header_length}a*")
          [
            extract_headers(encoded_header),
            extract_payload(encoded_payload)
          ]
        end

        def extract_headers(buffer)
          scanner = buffer
          headers = {}
          until scanner.bytesize == 0
            # header key
            key_length, scanner = scanner.unpack('Ca*')
            key, scanner = scanner.unpack("a#{key_length}a*")

            # header value
            type_index, scanner = scanner.unpack('Ca*')
            value_type = Types.types[type_index]
            unpack_pattern, value_length = Types.pattern[value_type]
            value = if !!unpack_pattern == unpack_pattern
              # boolean types won't have value specified
              unpack_pattern
            else
              value_length, scanner = scanner.unpack('S>a*') unless value_length
              unpacked_value, scanner = scanner.unpack("#{unpack_pattern || "a#{value_length}"}a*")
              unpacked_value
            end

            headers[key] = HeaderValue.new(
              format: @format,
              value: value,
              type: value_type
            )
          end
          headers
        end

        def extract_payload(encoded)
          encoded.bytesize <= ONE_MEGABYTE ?
            payload_stringio(encoded) :
            payload_tempfile(encoded)
        end

        def payload_stringio(encoded)
          StringIO.new(encoded)
        end

        def payload_tempfile(encoded)
          payload = Tempfile.new
          payload.binmode
          payload.write(encoded)
          payload.rewind
          payload
        end

        # Simple message class to hold decoded data
        class Message
          attr_reader :headers, :payload

          def initialize(headers:, payload:)
            @headers = headers
            @payload = payload
          end
        end

        # Header value wrapper
        class HeaderValue
          attr_reader :value, :type

          def initialize(format:, value:, type:)
            @format = format
            @value = value
            @type = type
          end
        end

        # Types module for header value types
        module Types
          def self.types
            {
              0 => :true,
              1 => :false,
              2 => :byte,
              3 => :short,
              4 => :integer,
              5 => :long,
              6 => :bytes,
              7 => :string,
              8 => :timestamp,
              9 => :uuid
            }
          end

          def self.pattern
            {
              true: [true, 0],
              false: [false, 0],
              byte: ['c', 1],
              short: ['s>', 2],
              integer: ['l>', 4],
              long: ['q>', 8],
              bytes: [nil, nil],
              string: [nil, nil],
              timestamp: ['q>', 8],
              uuid: ['H32', 16]
            }
          end
        end

        class Error < StandardError; end
      end
    end
  end
end
