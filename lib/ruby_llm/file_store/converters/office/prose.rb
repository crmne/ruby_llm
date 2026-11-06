# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      module Office
        # Reads the paragraphs and tables of a Word part or a slide: a line
        # for each paragraph, and a line with tabs between cells for each
        # table row. Word and PowerPoint share these element names.
        class Prose # :nodoc:
          SKIPPED = %w[tabs tabLst pPrChange rPr tblPr tcPr trPr sectPr Fallback].freeze
          BREAKS = { 'tab' => "\t", 'br' => "\n", 'cr' => "\n" }.freeze
          UNREAD_PLACEHOLDERS = %w[sldNum hdr ftr dt sldImg].freeze
          Paragraph = Struct.new(:text, :style, :list, :level, :outline, :marked)
          private_constant :SKIPPED, :BREAKS, :UNREAD_PLACEHOLDERS, :Paragraph

          def self.lines(xml, outline: nil)
            new(outline).read(xml)
          end

          def initialize(outline = nil)
            @outline = outline
            @sinks = [[]]
            @paragraphs = []
            @rows = []
            @shapes = []
            @capturing = false
          end

          def read(xml)
            Markup.scan(xml, skip: SKIPPED) do |kind, name, content|
              case kind
              when :text then text(content)
              when :open then opened(name, content)
              when :empty then empty(name, content)
              when :close then close(name)
              end
            end
            @sinks.first
          end

          private

          def text(content)
            @paragraphs.last.text << Markup.unescape(content) if @capturing && @paragraphs.any?
          end

          def opened(name, tag)
            case name
            when 'p' then open_paragraph
            when 't' then @capturing = true
            when 'tr' then @rows << []
            when 'tc' then @sinks << []
            when 'sp' then open_shape
            when 'ph' then placeholder(tag)
            else leaf(name, tag)
            end
          end

          def empty(name, tag)
            case name
            when 'tc' then @rows.last&.push('')
            when 'ph' then placeholder(tag)
            else leaf(name, tag)
            end
          end

          def leaf(name, tag)
            return unless @paragraphs.any?

            paragraph = @paragraphs.last
            case name
            when 'tab', 'br', 'cr' then paragraph.text << BREAKS[name]
            when 'pStyle' then paragraph.style = Markup.prefixed(tag, 'val')
            when 'numId' then paragraph.list = number(tag)
            when 'ilvl' then paragraph.level = number(tag)
            when 'outlineLvl' then paragraph.outline = number(tag)
            end
          end

          def number(tag)
            Markup.prefixed(tag, 'val').to_s[/\A\d{1,9}\z/]&.to_i
          end

          def close(name)
            case name
            when 't' then @capturing = false
            when 'p' then close_paragraph
            when 'tc' then close_cell
            when 'tr' then close_row
            when 'sp' then close_shape
            end
          end

          # A paragraph inside another, as in a text box, comes between the
          # text around it, so what the outer one holds so far goes first.
          def open_paragraph
            outer = @paragraphs.last
            emit(outer) if outer && !outer.text.empty?
            @paragraphs << Paragraph.new(+'')
          end

          def close_paragraph
            paragraph = @paragraphs.pop
            emit(paragraph) if paragraph
          end

          def emit(paragraph)
            marker = marker_of(paragraph)
            @sinks.last << "#{marker}#{paragraph.text}" unless paragraph.text.empty?
            paragraph.text = +''
          end

          # A list item counts wherever it is, but a table row keeps to one
          # line of plain cells.
          def marker_of(paragraph)
            return if paragraph.marked || @outline.nil?

            paragraph.marked = true
            marker = @outline.marker(style: paragraph.style, list: paragraph.list, level: paragraph.level,
                                     outline: paragraph.outline)
            marker if @sinks.size == 1
          end

          def close_cell
            return unless @sinks.size > 1

            cell = @sinks.pop.join(' ').tr("\t\n", '  ')
            @rows.last&.push(cell)
          end

          def close_row
            row = @rows.pop
            @sinks.last << row.join("\t") if row&.any? { |cell| !cell.empty? }
          end

          def open_shape
            @sinks << []
            @shapes << false
          end

          def placeholder(tag)
            @shapes[-1] = true if !@shapes.empty? && UNREAD_PLACEHOLDERS.include?(Markup.attribute(tag, 'type'))
          end

          def close_shape
            return if @sinks.size <= 1 || @shapes.empty?

            lines = @sinks.pop
            @sinks.last.concat(lines) unless @shapes.pop
          end
        end
      end
    end
  end
end
