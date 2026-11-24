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
          'Writes a text file, replacing any file at path. Read an existing file before you replace it. ' \
            'To change part of a file, use edit_file.'
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
          guarded_write do |write|
            path = path_for(path)
            file = changing(path) do
              refuse_inside_file(path)
              write.call(path, content.to_s)
            end
            "Wrote #{file.path} (#{file.human_size})."
          end
        end

        private

        def refuse_inside_file(path)
          parent = Pathname.new(path).ascend.drop(1).map(&:to_s).find { |folder| store[folder] }
          raise ToolError, "#{parent} is a file, not a folder" if parent
        end
      end
    end
  end
end
