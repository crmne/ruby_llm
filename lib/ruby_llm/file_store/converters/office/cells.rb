# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      module Office
        # Reads the rows of one Excel sheet as lines of tab-separated cells.
        class Cells # :nodoc:
          def initialize(strings)
            @strings = strings
            @rows = []
            @cell = nil
          end

          def read(xml)
            XML.each(xml) { |kind, value, source| kind == :text ? text(value) : tag(value, source) }
            @rows.map { |cells| cells.join("\t").rstrip }
          end

          private

          def text(value)
            @cell[:text] << value if @cell&.fetch(:reading)
          end

          def tag(name, source)
            case name
            when 'row' then @rows << []
            when 'c' then open_cell(source)
            when 'v', 't' then @cell&.store(:reading, true)
            when '/v', '/t' then @cell&.store(:reading, false)
            when '/c' then close_cell
            end
          end

          def open_cell(source)
            @cell = { column: column(XML.attribute(source, 'r')), type: XML.attribute(source, 't'), text: +'',
                      reading: false }
            close_cell if source.end_with?('/')
          end

          def close_cell
            row = @rows.last
            row[@cell[:column] || row.size] = value(@cell[:type], XML.unescape(@cell[:text])) if row && @cell
            @cell = nil
          end

          def column(reference)
            letters = reference.to_s[/\A[A-Z]{1,3}/]
            letters&.each_char&.reduce(0) { |index, letter| (index * 26) + (letter.ord - 64) }&.-(1)
          end

          def value(type, text)
            case type
            when 's' then @strings[text.to_i]
            when 'b' then text == '1' ? 'TRUE' : 'FALSE'
            else text
            end
          end
        end
      end
    end
  end
end
