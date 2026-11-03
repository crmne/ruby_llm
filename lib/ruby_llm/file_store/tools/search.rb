# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +search_files+ tool: lines matching a regular expression across
      # the text of the chat's files, like grep.
      class Search < Base # :nodoc:
        MAX_MATCHES = 100
        MAX_LINE = 300
        MAX_FILE_SIZE = 50 * 1024 * 1024

        def self.tool_name
          'search_files'
        end

        def description
          "Searches the text of this chat's files, text files and files whose text read_file already " \
            'extracted, for lines matching a regular expression, ignoring case, and returns each match with its ' \
            'path and line number. Read around a match with read_file and its offset. Pass path to search one ' \
            'file or folder.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'query' => { 'type' => 'string', 'description' => 'A regular expression, or plain words' },
              'path' => { 'type' => %w[string null],
                          'description' => 'A file or folder to search. Leave it out for all' }
            },
            'required' => %w[query],
            'additionalProperties' => false
          }
        end

        def execute(query:, path: nil)
          guarded do
            pattern = pattern_for(query.to_s)
            report(query, *search(pattern, scope(path)))
          end
        end

        private

        def scope(path)
          return store.list if path.to_s.strip.empty? || %w[. /].include?(path.to_s.strip)

          file = store.find(path_for(path))
          files = file ? [file] : store.list(path_for(path))
          raise ToolError, "There is no file or folder at #{path_for(path)}." if files.empty?

          files
        end

        def pattern_for(query)
          raise ToolError, 'query is empty.' if query.strip.empty?

          Regexp.new(query, Regexp::IGNORECASE, timeout: 1.0)
        rescue RegexpError
          Regexp.new(Regexp.escape(query), Regexp::IGNORECASE, timeout: 1.0)
        end

        def search(pattern, files)
          matches = []
          skipped = { none: [], unextracted: [] }
          files.each do |file|
            text = searchable_text(file)
            next skipped[text.is_a?(Symbol) ? text : :none] << file.path unless text.is_a?(String)

            text.each_line.with_index(1) do |line, number|
              next unless pattern.match?(line)

              matches << "#{file.path}:#{number}: #{line.chomp.strip[0, MAX_LINE]}"
              return [matches, skipped] if matches.size > MAX_MATCHES
            end
          rescue Regexp::TimeoutError
            raise ToolError, 'The regular expression took too long. Use a simpler one.'
          end
          [matches, skipped]
        end

        # Converters can cost money, like OCR, so search reads only text
        # files and conversions already made.
        def searchable_text(file)
          return '' if file.byte_size.zero?
          return if file.byte_size > MAX_FILE_SIZE

          cached = store.cached_text(file)
          return cached if cached
          return Converters::Text.call(store.attachment(file.path, file:)) if file.text?

          :unextracted if Converters.for_type(file.content_type, config:).any?
        end

        def report(query, matches, skipped)
          lines = matches.empty? ? ["No lines match #{query}."] : matches.first(MAX_MATCHES)
          if matches.size > MAX_MATCHES
            lines << "[More than #{MAX_MATCHES} matches. Narrow the query or search one folder.]"
          end
          if skipped[:unextracted].any?
            lines << "[Not searched, text not extracted yet: #{skipped[:unextracted].join(', ')}. " \
                     'Read a file with read_file to extract its text first.]'
          end
          lines << "[Not searched, no text: #{skipped[:none].join(', ')}]" if skipped[:none].any?
          lines.join("\n")
        end
      end
    end
  end
end
