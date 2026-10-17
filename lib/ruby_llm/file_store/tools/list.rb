# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +list_files+ tool: the chat's files, or those in one folder,
      # with their sizes and types.
      class List < Base # :nodoc:
        MAX_FILES = 500

        def self.tool_name
          'list_files'
        end

        def description
          "Lists the files in this chat's file store, with their sizes and types: files people attached, " \
            'files tools returned, long tool results, and files you or your code wrote. Pass path to list ' \
            'one folder.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => %w[string null], 'description' => 'A folder to list. Leave it out for every file' }
            },
            'additionalProperties' => false
          }
        end

        def execute(path: nil)
          guarded do
            folder = path_for(path) unless path.to_s.strip.empty? || %w[. /].include?(path.to_s.strip)
            files = store.list(folder)
            next(folder ? "There are no files in #{folder}." : 'There are no files yet.') if files.empty?

            lines = files.first(MAX_FILES).map { |file| "#{file.path}\t#{file.human_size}\t#{file.content_type}" }
            lines << "[#{files.size - MAX_FILES} more files. List a folder to see them.]" if files.size > MAX_FILES
            lines.join("\n")
          end
        end
      end
    end
  end
end
