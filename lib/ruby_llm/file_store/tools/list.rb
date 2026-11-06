# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +list_files+ tool: the chat's files, those in one folder, or
      # those matching a glob, with their sizes and types.
      class List < Base # :nodoc:
        MAX_FILES = 200

        def self.tool_name
          'list_files'
        end

        def description
          'Lists the files, with sizes and types. Pass path for one folder, and pattern for a glob: ' \
            '*.csv matches names in any folder, reports/**/*.csv matches paths.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => %w[string null], 'description' => 'A folder to list' },
              'pattern' => { 'type' => %w[string null], 'description' => 'A glob, like *.md or reports/**/*.csv' }
            },
            'additionalProperties' => false
          }
        end

        def execute(path: nil, pattern: nil)
          guarded do
            folder = folder_for(path)
            files = store.list(folder)
            pattern = pattern.to_s.strip.then { |glob| glob unless glob.empty? }
            files = files.select { |file| FileStore.match?(file.path, pattern, inside: folder) } if pattern
            next empty(folder, pattern) if files.empty?

            lines = files.first(MAX_FILES).map { |file| "#{file.path}\t#{file.human_size}\t#{file.content_type}" }
            if files.size > MAX_FILES
              lines << "[#{files.size - MAX_FILES} more files. Narrow the list with path or pattern.]"
            end
            lines.join("\n")
          end
        end

        private

        def empty(folder, pattern)
          return "No files#{" in #{folder}" if folder} match #{pattern}." if pattern

          folder ? "There are no files in #{folder}." : 'There are no files yet.'
        end
      end
    end
  end
end
