# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +write_file+ tool: creates a text file in the chat's files, or
      # replaces one.
      class Write < Base # :nodoc:
        def self.tool_name
          'write_file'
        end

        def description
          "Writes a text file to this chat's file store, replacing any file at that path. Use it for notes, " \
            'drafts, data, and results you want to keep or come back to. To change part of a file, use edit_file.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => 'string', 'description' => 'Where to write, such as notes/summary.md' },
              'content' => { 'type' => 'string', 'description' => 'The complete content of the file' }
            },
            'required' => %w[path content],
            'additionalProperties' => false
          }
        end

        def execute(path:, content:)
          guarded do
            file = write(path_for(path), content.to_s)
            "Wrote #{file.path} (#{file.human_size})."
          end
        end
      end
    end
  end
end
