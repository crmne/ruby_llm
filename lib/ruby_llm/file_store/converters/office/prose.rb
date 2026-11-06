# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      module Office
        # Reads the paragraphs and tables of a Word part or a slide: a line
        # for each paragraph, and a line with tabs between cells for each
        # table row. Word and PowerPoint share these element names.
        class Prose # :nodoc:
          SKIPPED = %w[pPr rPr tblPr tcPr trPr sectPr Fallback].freeze
          BREAKS = { 'tab' => "\t", 'br' => "\n", 'cr' => "\n" }.freeze
          UNREAD_PLACEHOLDERS = %w[sldNum hdr ftr dt sldImg].freeze
          private_constant :SKIPPED, :BREAKS, :UNREAD_PLACEHOLDERS

          def self.lines(xml)
            new.read(xml)
          end

          def initialize
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
            @paragraphs.last << Markup.unescape(content) if @capturing && @paragraphs.any?
          end

          def opened(name, tag)
            case name
            when 'p' then @paragraphs << +''
            when 't' then @capturing = true
            when 'tr' then @rows << []
            when 'tc' then @sinks << []
            when 'sp' then open_shape
            when 'ph' then placeholder(tag)
            when 'tab', 'br', 'cr' then @paragraphs.last&.<<(BREAKS[name])
            end
          end

          def empty(name, tag)
            case name
            when 'tab', 'br', 'cr' then @paragraphs.last&.<<(BREAKS[name])
            when 'tc' then @rows.last&.push('')
            when 'ph' then placeholder(tag)
            end
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

          def close_paragraph
            text = @paragraphs.pop
            @sinks.last << text unless text.nil? || text.empty?
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
