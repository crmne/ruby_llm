# frozen_string_literal: true

require 'zlib'

module RubyLLM
  class FileStore
    module Converters
      module Office
        # The entries of a zip archive, read from its central directory,
        # with Zip64 sizes when an entry or the directory needs them. It
        # inflates at most MAX_SIZE in all, counting what comes out rather
        # than what an entry declares, so a small archive cannot fill the
        # memory.
        class Zip # :nodoc:
          class Error < StandardError; end # :nodoc:

          END_OF_DIRECTORY = "PK\x05\x06".b
          ZIP64_LOCATOR = "PK\x06\x07".b
          ZIP64_END_OF_DIRECTORY = "PK\x06\x06".b
          DIRECTORY_ENTRY = "PK\x01\x02".b
          LOCAL_ENTRY = "PK\x03\x04".b
          MASKED = 0xFFFFFFFF
          MASKED_COUNT = 0xFFFF
          ZIP64_EXTRA = 1
          INFLATE_STEP = 4096
          private_constant :END_OF_DIRECTORY, :ZIP64_LOCATOR, :ZIP64_END_OF_DIRECTORY, :DIRECTORY_ENTRY,
                           :LOCAL_ENTRY, :MASKED, :MASKED_COUNT, :ZIP64_EXTRA, :INFLATE_STEP

          def initialize(bytes)
            @bytes = bytes
            @inflated = 0
            @entries = read_directory
          end

          def names
            @entries.keys
          end

          def include?(name)
            @entries.key?(name)
          end

          def [](name)
            entry = @entries[name]
            entry && extract(**entry)
          end

          private

          def slice(offset, length)
            part = @bytes.byteslice(offset, length)
            raise Error, 'truncated zip archive' unless part&.bytesize == length

            part
          end

          def read_directory
            finish = @bytes.rindex(END_OF_DIRECTORY) || raise(Error, 'not a zip archive')
            count, _size, offset = slice(finish + 10, 10).unpack('vVV')
            count, offset = zip64_directory(finish) if count == MASKED_COUNT || offset == MASKED
            count.times.with_object({}) { |_index, entries| offset = read_entry(offset, entries) }
          end

          def zip64_directory(finish)
            raise Error, 'bad Zip64 locator' unless finish >= 20 && slice(finish - 20, 4) == ZIP64_LOCATOR

            record = slice(finish - 12, 8).unpack1('Q<')
            raise Error, 'bad Zip64 directory' unless slice(record, 4) == ZIP64_END_OF_DIRECTORY

            slice(record + 32, 24).unpack('Q<x8Q<')
          end

          def read_entry(offset, entries)
            raise Error, 'bad central directory' unless slice(offset, 4) == DIRECTORY_ENTRY

            method, compressed, size, name_length, extra_length, comment_length =
              slice(offset + 10, 24).unpack('vx8VVvvv')
            local = slice(offset + 42, 4).unpack1('V')
            raw_name = slice(offset + 46, name_length)
            name = raw_name.tr('\\', '/').force_encoding(Encoding::UTF_8)
            extra = slice(offset + 46 + name_length, extra_length)
            alias_of_entry = raw_name.include?('\\') && entries.key?(name)
            entries[name] = { method:, **sizes(extra, size:, compressed:, local:) } unless alias_of_entry
            offset + 46 + name_length + extra_length + comment_length
          end

          # Returns the three values, taking each masked one from the Zip64
          # extra field, in the order the format gives them, or +nil+ when
          # the field does not have it.
          def sizes(extra, values)
            return values unless values.value?(MASKED)

            field = zip64_field(extra).unpack('Q<*')
            values.transform_values { |value| value == MASKED ? field.shift : value }
          end

          def zip64_field(extra)
            position = 0
            while position + 4 <= extra.bytesize
              id, length = extra.byteslice(position, 4).unpack('vv')
              return extra.byteslice(position + 4, length).to_s if id == ZIP64_EXTRA

              position += 4 + length
            end
            ''.b
          end

          def extract(method:, size:, compressed:, local:)
            raise Error, 'bad local entry' unless local && slice(local, 4) == LOCAL_ENTRY

            name_length, extra_length = slice(local + 26, 4).unpack('vv')
            start = local + 30 + name_length + extra_length
            data = compressed ? slice(start, compressed) : @bytes.byteslice(start..)
            limit = [size, MAX_SIZE - @inflated].compact.min
            output = contents(method, data, limit)
            @inflated += output.bytesize
            output
          end

          def contents(method, data, limit)
            case method
            when 0
              raise Error, 'entry too large' if data.bytesize > limit

              data
            when 8 then inflate(data, limit)
            else raise Error, "unsupported compression #{method}"
            end
          end

          def inflate(data, limit)
            inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
            output = +''.b
            (0...data.bytesize).step(INFLATE_STEP) do |offset|
              output << inflater.inflate(data.byteslice(offset, INFLATE_STEP))
              raise Error, 'entry too large' if output.bytesize > limit
              break if inflater.finished?
            end
            raise Error, 'truncated entry' unless inflater.finished?

            output
          ensure
            inflater&.close
          end
        end
      end
    end
  end
end
