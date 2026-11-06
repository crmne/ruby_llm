# frozen_string_literal: true

require 'date'

module RubyLLM
  class FileStore
    module Converters
      module Office
        # Reads the sheets of an Excel workbook: a heading for each, and a
        # line with tabs between cells for each row that holds anything.
        class Workbook # :nodoc:
          MAX_COLUMN = 16_384
          MAX_SERIAL = 2_958_465
          SECONDS_A_DAY = 86_400
          BUILT_IN_DATE_FORMATS = [*14..22, *27..36, *45..47, *50..58].freeze
          TRUTHY = %w[1 true on].freeze
          private_constant :MAX_COLUMN, :MAX_SERIAL, :SECONDS_A_DAY, :BUILT_IN_DATE_FORMATS, :TRUTHY

          def initialize(zip, sheets)
            @zip = zip
            @sheets = sheets
            @size = 0
          end

          def text
            @strings = shared_strings
            @date_styles = date_styles
            @date1904 = date1904?
            @sheets.each_with_index.map do |(part, tag), index|
              ["## #{Markup.attribute(tag, 'name') || "Sheet #{index + 1}"}", *rows(@zip[part])].join("\n")
            end.join("\n\n")
          end

          private

          def shared_strings
            strings = []
            capturing = false
            Markup.scan(@zip['xl/sharedStrings.xml'], skip: %w[rPh]) do |kind, name, content|
              case kind
              when :open
                strings << +'' if name == 'si'
                capturing = true if name == 't'
              when :close then capturing = false if name == 't'
              when :text then strings.last << Markup.unescape(content) if capturing && strings.any?
              end
            end
            strings
          end

          def rows(xml)
            @lines = []
            @row = @cell = @value = nil
            @capturing = false
            Markup.scan(xml, skip: %w[rPh f]) do |kind, name, content|
              case kind
              when :open then opened(name, content)
              when :empty then place(@row, content, '') if name == 'c' && @row
              when :text then @value << content if @capturing && @value
              when :close then closed(name)
              end
            end
            @lines
          end

          def opened(name, tag)
            case name
            when 'row' then @row = []
            when 'c'
              @cell = tag
              @value = +''.b
            when 'v', 't' then @capturing = true
            end
          end

          def closed(name)
            case name
            when 'v', 't' then @capturing = false
            when 'c' then place(@row, @cell, render(@cell, @value)) if @row && @cell
            when 'row'
              add_row(@lines, @row) if @row
              @row = nil
            end
          end

          def add_row(lines, row)
            return if row.all?(&:empty?)

            line = row.join("\t")
            @size += line.bytesize
            raise Zip::Error, 'workbook too large' if @size > MAX_SIZE

            lines << line
          end

          def place(row, tag, value)
            column = column_of(tag)
            row.fill('', row.size...column) if column
            row << value
          end

          def column_of(tag)
            letters = Markup.attribute(tag, 'r').to_s[/\A([A-Z]{1,3})\d+\z/, 1]
            column = letters&.each_char&.inject(0) { |sum, letter| (sum * 26) + letter.ord - 64 }
            column.pred if column && column <= MAX_COLUMN
          end

          def render(tag, value)
            case Markup.attribute(tag, 't')
            when 's' then @strings[value.to_i].to_s
            when 'b' then value == '1' ? 'TRUE' : 'FALSE'
            when nil, 'n' then number(tag, Markup.unescape(value))
            else Markup.unescape(value)
            end
          end

          def number(tag, value)
            style = Markup.attribute(tag, 's')
            return value unless style && @date_styles[style.to_i]

            serial = Float(value, exception: false)
            serial && serial >= 0 && serial <= MAX_SERIAL ? date(serial) || value : value
          end

          def date(serial)
            day = serial.floor
            seconds = ((serial - day) * SECONDS_A_DAY).round
            if seconds == SECONDS_A_DAY
              day += 1
              seconds = 0
            end
            time = format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours: seconds / 3600,
                                                                     minutes: seconds % 3600 / 60,
                                                                     seconds: seconds % 60)
            return time if day.zero? && seconds.positive?

            calendar = calendar_day(day)
            return unless calendar

            seconds.zero? ? calendar : "#{calendar} #{time}"
          end

          # Excel counts 1900 as a leap year, so serial 60 is a day that never
          # was, and the serials after it are one day ahead of the calendar.
          def calendar_day(day)
            return (Date.new(1904, 1, 1) + day).iso8601 if @date1904
            return if day.zero?
            return '1900-02-29' if day == 60

            (Date.new(1899, 12, day < 60 ? 31 : 30) + day).iso8601
          end

          def date_styles
            formats = {}
            styles = []
            in_cell_formats = false
            Markup.scan(@zip['xl/styles.xml']) do |kind, name, tag|
              case name
              when 'numFmt' then formats[Markup.attribute(tag, 'numFmtId').to_i] = Markup.attribute(tag, 'formatCode')
              when 'cellXfs' then in_cell_formats = kind == :open
              when 'xf' then if in_cell_formats && tag
                               styles << date_format?(Markup.attribute(tag, 'numFmtId').to_i,
                                                      formats)
                             end
              end
            end
            styles
          end

          def date_format?(id, formats)
            code = formats[id]
            return BUILT_IN_DATE_FORMATS.include?(id) unless code
            return false if code.match?(/\[(?:h+|m+|s+)\]/i)

            code.gsub(/"[^"]*"|\\.|_.|\*.|\[[^\]]*\]/, '').match?(/[ymdhs]/i)
          end

          def date1904?
            Markup.tags(@zip['xl/workbook.xml'], 'workbookPr').any? do |tag|
              TRUTHY.include?(Markup.attribute(tag, 'date1904'))
            end
          end
        end
      end
    end
  end
end
