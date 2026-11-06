# frozen_string_literal: true

require 'pathname'
require 'zlib'

module RubyLLM
  class FileStore
    module Converters
      # Reads the text of Word documents, Excel workbooks, and PowerPoint
      # decks (.docx, .xlsx, .pptx) on this machine, with no service and no
      # cost: a paragraph per line, a row per line with tabs between cells,
      # and a heading for each sheet and slide. Text comes back in document
      # order, without layout, images, or computed formatting.
      module Office
        TYPES = {
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => :document,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => :workbook,
          'application/vnd.openxmlformats-officedocument.presentationml.presentation' => :deck
        }.freeze # :nodoc:
        MAX_SIZE = 50 * 1024 * 1024 # :nodoc:
        ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'" }.freeze
        PREFIX = '(?:[\w.-]+:)?'
        private_constant :ENTITIES, :PREFIX

        class << self
          # Returns the text of +attachment+, or +nil+ when it is not a
          # document, workbook, or deck it can read.
          def call(attachment)
            kind = TYPES[attachment.mime_type]
            return unless kind

            send(kind, Zip.new(attachment.content.to_s.b))
          rescue Zip::Error, Zlib::Error
            nil
          end

          # Returns +true+: it reads files on this machine, for free.
          def local?
            true
          end

          private

          def document(zip)
            paragraphs(zip['word/document.xml'])
          end

          def workbook(zip)
            strings = zip['xl/sharedStrings.xml'].to_s.scan(element('si')).map { |(item)| runs(item) }
            parts(zip, 'xl', 'workbook.xml', 'sheet', %r{\Axl/worksheets/[^/]+\.xml\z})
              .each_with_index.map do |(part, tag), index|
                rows = zip[part].to_s.scan(element('row')).map { |(row)| cells(row, strings).join("\t") }
                ["## #{unescape(tag.to_s[/\bname="([^"]*)"/, 1] || "Sheet #{index + 1}")}", *rows].join("\n")
              end.join("\n\n")
          end

          def deck(zip)
            parts(zip, 'ppt', 'presentation.xml', 'sldId', %r{\Appt/slides/[^/]+\.xml\z})
              .each_with_index.map do |(part, _tag), index|
                "## Slide #{index + 1}\n\n#{paragraphs(zip[part])}"
              end.join("\n\n")
          end

          # Returns each part the +owner+ lists with a +tag+, in its order,
          # with that tag, or the parts matching +fallback+ in name order
          # when the listing doesn't resolve.
          def parts(zip, folder, owner, tag, fallback)
            targets = relationships(zip, "#{folder}/_rels/#{owner}.rels", folder)
            listed = zip["#{folder}/#{owner}"].to_s.scan(/<#{PREFIX}#{tag}\b[^>]*>/).filter_map do |listing|
              part = targets[listing[/\s[\w.-]+:id="([^"]*)"/, 1]]
              [part, listing] if part && zip.names.include?(part)
            end
            return listed if listed.any?

            zip.names.grep(fallback).sort_by { |name| name[/\d+/].to_i }.map { |name| [name, nil] }
          end

          def relationships(zip, path, folder)
            zip[path].to_s.scan(/<#{PREFIX}Relationship\b[^>]*>/o).to_h do |relationship|
              target = relationship[/\bTarget="([^"]*)"/, 1].to_s
              part = target.start_with?('/') ? target.delete_prefix('/') : "#{folder}/#{target}"
              [relationship[/\bId="([^"]*)"/, 1], Pathname(part).cleanpath.to_s]
            end
          end

          def element(name)
            %r{<#{PREFIX}#{name}(?:\s[^>]*[^/>])?>(.*?)</#{PREFIX}#{name}>}m
          end

          def paragraphs(xml)
            xml.to_s.scan(element('p')).map { |(paragraph)| runs(paragraph) }.reject(&:empty?).join("\n")
          end

          def runs(xml)
            xml.scan(element('t')).map { |(text)| unescape(text) }.join
          end

          def cells(row, strings)
            pattern = %r{<#{PREFIX}c\b([^>]*?)(?:/>|>(.*?)</#{PREFIX}c>)}mo
            row.scan(pattern).each_with_object([]) do |(attributes, body), values|
              column = column_of(attributes)
              values.fill('', values.size...column) if column
              values << cell(attributes, body.to_s, strings)
            end
          end

          def column_of(attributes)
            letters = attributes[/\br="([A-Z]+)\d+"/, 1]
            letters&.each_char&.inject(0) { |sum, letter| (sum * 26) + letter.ord - 64 }&.pred
          end

          def cell(attributes, body, strings)
            value = body[element('v'), 1]
            case attributes[/\bt="([^"]*)"/, 1]
            when 's' then strings[value.to_i].to_s
            when 'inlineStr' then runs(body)
            else unescape(value.to_s)
            end
          end

          def unescape(text)
            text.to_s.dup.force_encoding(Encoding::UTF_8).scrub.gsub(/&(?:#(\d+)|#x(\h+)|(amp|lt|gt|quot|apos));/) do
              decimal = Regexp.last_match(1)
              hex = Regexp.last_match(2)
              next ENTITIES.fetch(Regexp.last_match(3)) unless decimal || hex

              character(decimal ? decimal.to_i : hex.to_i(16))
            end
          end

          def character(code)
            [code].pack('U').then { |text| text.valid_encoding? ? text : '' }
          rescue RangeError
            ''
          end
        end

        # The entries of a zip archive, read from its central directory.
        # It inflates at most MAX_SIZE in all, so a small archive cannot
        # fill the memory.
        class Zip # :nodoc:
          class Error < StandardError; end # :nodoc:

          END_OF_DIRECTORY = "PK\x05\x06".b
          DIRECTORY_ENTRY = "PK\x01\x02".b
          LOCAL_ENTRY = "PK\x03\x04".b
          INFLATE_STEP = 4096
          private_constant :END_OF_DIRECTORY, :DIRECTORY_ENTRY, :LOCAL_ENTRY, :INFLATE_STEP

          def initialize(bytes)
            @bytes = bytes
            @inflated = 0
            @entries = read_directory
          end

          def names
            @entries.keys
          end

          def [](name)
            entry = @entries[name]
            entry && extract(*entry)
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
            count.times.with_object({}) do |_index, entries|
              offset = read_entry(offset, entries)
            end
          end

          def read_entry(offset, entries)
            raise Error, 'bad central directory' unless slice(offset, 4) == DIRECTORY_ENTRY

            method, compressed, size, name_length, extra_length, comment_length =
              slice(offset + 10, 24).unpack('vx8VVvvv')
            local = slice(offset + 42, 4).unpack1('V')
            name = slice(offset + 46, name_length).force_encoding(Encoding::UTF_8)
            entries[name] = [method, compressed, size, local]
            offset + 46 + name_length + extra_length + comment_length
          end

          def extract(method, compressed, size, local)
            @inflated += size
            raise Error, 'archive too large' if @inflated > MAX_SIZE
            raise Error, 'bad local entry' unless slice(local, 4) == LOCAL_ENTRY

            name_length, extra_length = slice(local + 26, 4).unpack('vv')
            data = slice(local + 30 + name_length + extra_length, compressed)
            case method
            when 0 then data
            when 8 then inflate(data, size)
            else raise Error, "unsupported compression #{method}"
            end
          end

          def inflate(data, size)
            inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
            output = +''
            (0...data.bytesize).step(INFLATE_STEP) do |offset|
              output << inflater.inflate(data.byteslice(offset, INFLATE_STEP))
              raise Error, 'entry larger than it says' if output.bytesize > size
            end
            output
          ensure
            inflater&.close
          end
        end
      end
    end
  end
end
