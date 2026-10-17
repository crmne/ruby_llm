# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +read_file+ tool: a range of a file's text, by lines or by
      # characters, with converted text for PDFs and Office files. Images,
      # and PDFs without text, come back as an attachment the model sees.
      class Read < Base # :nodoc:
        MAX_LINES = 1_000
        MAX_CHARACTERS = 20_000
        MAX_LINE = 2_000
        UNITS = %w[lines characters].freeze

        def self.tool_name
          'read_file'
        end

        def description
          "Reads a file from this chat's file store. Text comes back with line numbers, #{MAX_LINES} lines " \
            "or #{MAX_CHARACTERS} characters at a time: pass offset and limit to read further. PDFs, Word, " \
            'Excel, and PowerPoint files come back as their text, and images as the image itself. With ' \
            'unit "characters", offset and limit count characters instead of lines, for files with very ' \
            'long lines.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => 'string', 'description' => 'The file to read' },
              'offset' => { 'type' => %w[integer null],
                            'description' => 'The line to start at, from 1, or the character, from 0' },
              'limit' => { 'type' => %w[integer null], 'description' => 'How many lines or characters to read' },
              'unit' => { 'type' => %w[string null], 'enum' => [*UNITS, nil],
                          'description' => 'lines (the default) or characters' }
            },
            'required' => %w[path],
            'additionalProperties' => false
          }
        end

        def execute(path:, offset: nil, limit: nil, unit: nil)
          guarded do
            file = file_at(path)
            unit = (unit || 'lines').to_s
            raise ToolError, "unit is lines or characters, not #{unit}." unless UNITS.include?(unit)
            next "#{file.path} is empty." if file.byte_size.zero?

            text = store.text(file.path, config:)
            next unreadable(file) if text.nil?

            unit == 'characters' ? characters(file, text, offset, limit) : lines(file, text, offset, limit)
          end
        end

        private

        def lines(file, text, offset, limit)
          all = text.lines
          start = [offset.to_i, 1].max
          raise ToolError, "#{file.path} has #{all.size} lines; offset #{start} is past the end." if
            start > all.size && !all.empty?

          count = limit.to_i.positive? ? [limit.to_i, MAX_LINES].min : MAX_LINES
          shown = []
          size = 0
          all.drop(start - 1).first(count).each_with_index do |line, index|
            line = shorten(line.chomp)
            break if size + line.size > MAX_CHARACTERS && shown.any?

            shown << format('%<number>6d	%<line>s', number: start + index, line:)
            size += line.size
          end
          last = start + shown.size - 1
          [header(file, "lines #{start}-#{last} of #{all.size}"), *shown, more_lines(all.size, last)].compact.join("\n")
        end

        def characters(file, text, offset, limit)
          start = [offset.to_i, 0].max
          count = limit.to_i.positive? ? [limit.to_i, MAX_CHARACTERS].min : MAX_CHARACTERS
          part = text[start, count].to_s
          finish = start + part.size
          more = "[#{text.size - finish} more characters. Continue with offset #{finish}.]" if finish < text.size
          [header(file, "characters #{start}-#{finish} of #{text.size}"), part, more].compact.join("\n")
        end

        def header(file, range)
          source = " (text read from #{file.content_type})" unless file.text?
          "#{file.path}#{source}, #{range}:"
        end

        def more_lines(total, last)
          "[#{total - last} more lines. Continue with offset #{last + 1}.]" if last < total
        end

        def shorten(line)
          return line if line.size <= MAX_LINE

          "#{line[0, MAX_LINE]} [line cut: #{line.size - MAX_LINE} more characters, read them with unit characters]"
        end

        def unreadable(file)
          type = Files::MimeType
          if type.image?(file.content_type) || type.pdf?(file.content_type)
            return ["#{file.path} (#{file.content_type}, #{file.human_size}) is attached to this result.",
                    store.attachment(file.path, file:)]
          end

          { error: "#{file.path} is #{file.content_type} and has no text to read. Work with it in code if you " \
                   'can run code, or describe it from its name.' }
        end
      end
    end
  end
end
