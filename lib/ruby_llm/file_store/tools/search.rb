# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +search_files+ tool: lines matching a regular expression across
      # the text of the chat's files, or the files that have one, like grep.
      class Search < Base # :nodoc:
        MAX_MATCHES = 100
        MAX_CHARACTERS = 20_000
        MAX_CONTEXT = 10
        MAX_LINE = 300
        MAX_FILE_SIZE = 50 * 1024 * 1024
        MAX_SECONDS = 10

        def self.tool_name
          'search_files'
        end

        def description
          'Searches the text of the files for lines matching a regular expression, like grep, and returns ' \
            'path:line: text. Start with files_only to see which files match, then read them with read_file. ' \
            'Files whose text read_file has not extracted yet are skipped and named.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'query' => { 'type' => 'string', 'description' => 'A regular expression, or plain words' },
              'path' => { 'type' => %w[string null], 'description' => 'A file or folder to search' },
              'glob' => { 'type' => %w[string null], 'description' => 'Only files matching this, like *.md' },
              'context' => { 'type' => %w[integer null], 'description' => 'Lines to show around each match' },
              'case_sensitive' => { 'type' => %w[boolean null], 'description' => 'Match case. Default: false' },
              'files_only' => { 'type' => %w[boolean null], 'description' => 'Return only the matching paths' }
            },
            'required' => %w[query],
            'additionalProperties' => false
          }
        end

        def execute(query:, path: nil, glob: nil, context: nil, case_sensitive: false, files_only: false)
          guarded do
            pattern = pattern_for(query.to_s, case_sensitive)
            glob = nil if glob.to_s.strip.empty?
            files = scope(path, glob)
            next "No files match #{glob}." if files.empty? && glob

            Run.new(pattern, context: context.to_i.clamp(0, MAX_CONTEXT), files_only:).call(files) do |file|
              searchable_text(file)
            end.report(query)
          end
        end

        private

        def scope(path, glob)
          folder = folder_for(path)
          files = folder ? files_at(folder) : store.list
          return files unless glob

          files.select { |file| FileStore.match?(file.path, glob, inside: folder) }
        end

        def files_at(folder)
          file = store[folder]
          files = file ? [file] : store.list(folder)
          raise ToolError, "There is no file or folder at #{folder}." if files.empty?

          files
        end

        def pattern_for(query, case_sensitive)
          raise ToolError, 'query is empty.' if query.strip.empty?

          options = case_sensitive ? 0 : Regexp::IGNORECASE
          begin
            Regexp.new(query, options, timeout: 1.0)
          rescue RegexpError
            Regexp.new(Regexp.escape(query), options, timeout: 1.0)
          end
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

        # One search: walks the files, collects what it shows, and stops at
        # its limits.
        class Run # :nodoc:
          def initialize(pattern, context:, files_only:)
            @pattern = pattern
            @context = context
            @files_only = files_only
            @lines = []
            @size = 0
            @matches = 0
            @skipped = { none: [], unextracted: [] }
            @stopped = nil
            @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_SECONDS
          end

          def call(files)
            files.each do |file|
              break if @stopped

              text = yield(file)
              next @skipped[text.is_a?(Symbol) ? text : :none] << file.path unless text.is_a?(String)

              search(file.path, text.lines)
            end
            self
          rescue Regexp::TimeoutError
            raise Base::ToolError, 'The regular expression took too long. Use a simpler one.'
          end

          def report(query)
            lines = @lines.empty? ? ["No lines match #{query}."] : @lines.dup
            lines << notice if @stopped
            if @skipped[:unextracted].any?
              unextracted = @skipped[:unextracted]
              lines << "[Not searched, text not extracted yet: #{unextracted.join(', ')}. " \
                       "read_file extracts #{unextracted.one? ? 'it' : 'them'}.]"
            end
            lines << "[Not searched, no text: #{@skipped[:none].join(', ')}]" if @skipped[:none].any?
            lines.join("\n")
          end

          private

          def search(path, lines)
            matched = []
            lines.each_with_index do |line, index|
              return stop(:time) if late?
              next unless @pattern.match?(line)
              return show([path]) if @files_only

              matched << index
            end
            show_matches(path, lines, matched)
          end

          def show_matches(path, lines, matched)
            hits = matched.to_set
            windows(matched, lines.size).each_with_index.all? do |(first, last), index|
              (index.zero? || @context.zero? || show(['--'], match: false)) &&
                (first..last).all? do |number|
                  mark = hits.include?(number) ? ':' : '-'
                  show(["#{path}#{mark}#{number + 1}#{mark} #{clean(lines[number])}"], match: mark == ':')
                end
            end
          end

          def windows(matched, size)
            matched.each_with_object([]) do |index, windows|
              first = [index - @context, 0].max
              last = [index + @context, size - 1].min
              next windows.last[1] = last if windows.any? && first <= windows.last[1] + 1

              windows << [first, last]
            end
          end

          def show(lines, match: true)
            text = lines.join("\n")
            return stop(:size) if @size + text.size > MAX_CHARACTERS && @lines.any?
            return stop(:size) if match && @matches >= MAX_MATCHES

            @lines.concat(lines)
            @size += text.size + 1
            @matches += 1 if match
            true
          end

          def clean(line)
            line.chomp.strip[0, MAX_LINE]
          end

          def late?
            Process.clock_gettime(Process::CLOCK_MONOTONIC) > @deadline
          end

          def stop(reason)
            @stopped ||= reason
            nil
          end

          def notice
            if @stopped == :time
              '[The search took too long and stopped. Narrow it with path or glob.]'
            else
              '[More matches. Narrow the query, path, or glob.]'
            end
          end
        end
      end
    end
  end
end
