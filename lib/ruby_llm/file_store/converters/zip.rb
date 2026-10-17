# frozen_string_literal: true

require 'zlib'

module RubyLLM
  class FileStore
    module Converters
      # Reads the entries of a ZIP archive held in memory, enough for the
      # Office formats: stored and deflated entries, no encryption or
      # ZIP64. Refuses entries that inflate past MAX_SIZE.
      class Zip # :nodoc:
        class Error < StandardError; end # :nodoc:

        MAX_SIZE = 64 * 1024 * 1024
        CHUNK = 4 * 1024
        END_OF_DIRECTORY = "PK\x05\x06".b
        DIRECTORY_ENTRY = "PK\x01\x02".b
        LOCAL_HEADER = "PK\x03\x04".b

        def initialize(data)
          @data = data
          @entries = read_directory
        end

        def names
          @entries.keys
        end

        def include?(name)
          @entries.key?(name)
        end

        def read(name)
          method, compressed_size, offset = @entries.fetch(name) { raise Error, "No entry #{name}" }
          raise Error, 'Corrupt local header' unless @data.byteslice(offset, 4) == LOCAL_HEADER

          name_length, extra_length = @data.byteslice(offset + 26, 4).unpack('vv')
          body = @data.byteslice(offset + 30 + name_length + extra_length, compressed_size).to_s
          content = case method
                    when 0 then body
                    when 8 then inflate(body)
                    else raise Error, "Unsupported compression method #{method}"
                    end
          content.force_encoding(Encoding::UTF_8).scrub
        end

        private

        def read_directory
          position = @data.rindex(END_OF_DIRECTORY, [@data.bytesize - 22, 0].max) ||
                     raise(Error, 'Not a ZIP archive')
          count, _size, offset = @data.byteslice(position + 10, 10).unpack('vVV')
          (1..count).each_with_object({}) do |_, entries|
            raise Error, 'Corrupt central directory' unless @data.byteslice(offset, 4) == DIRECTORY_ENTRY

            method, = @data.byteslice(offset + 10, 2).unpack('v')
            compressed_size, = @data.byteslice(offset + 20, 4).unpack('V')
            name_length, extra_length, comment_length = @data.byteslice(offset + 28, 6).unpack('vvv')
            local_offset, = @data.byteslice(offset + 42, 4).unpack('V')
            name = @data.byteslice(offset + 46, name_length).force_encoding(Encoding::UTF_8)
            entries[name] = [method, compressed_size, local_offset]
            offset += 46 + name_length + extra_length + comment_length
          end
        rescue NoMethodError, TypeError, ArgumentError
          raise Error, 'Corrupt ZIP archive'
        end

        def inflate(body)
          inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
          output = +''
          (0...body.bytesize).step(CHUNK) do |start|
            output << inflater.inflate(body.byteslice(start, CHUNK))
            raise Error, 'Entry too large' if output.bytesize > MAX_SIZE
          end
          output << inflater.finish
          raise Error, 'Entry too large' if output.bytesize > MAX_SIZE

          output
        rescue Zlib::Error
          raise Error, 'Corrupt deflated entry'
        ensure
          inflater&.close
        end
      end
    end
  end
end
