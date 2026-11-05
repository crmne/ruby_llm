# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +delete_file+ tool: deletes one file. Chats get it only when
      # they ask for it.
      class Delete < Base # :nodoc:
        def self.tool_name
          'delete_file'
        end

        def description
          'Deletes one file.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => 'string', 'description' => 'The file to delete' }
            },
            'required' => %w[path],
            'additionalProperties' => false
          }
        end

        def execute(path:)
          guarded do
            path = path_for(path)
            store.with_lock { delete(path) }
          end
        end

        private

        def delete(path)
          file = store.delete(path)
          raise ToolError, "There is no file at #{path}. List the files with list_files." unless file

          "Deleted #{file.path}."
        rescue ArgumentError
          raise ToolError, "#{path} is a folder. Delete its files one by one."
        end
      end
    end
  end
end
