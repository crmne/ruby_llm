# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +edit_file+ tool: replaces one exact span of a text file.
      class Edit < Base # :nodoc:
        def self.tool_name
          'edit_file'
        end

        def description
          'Changes a text file you have read by replacing old_text, which must appear exactly once, with ' \
            'new_text. Include surrounding text to make old_text unique, or set replace_all.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => 'string', 'description' => 'The file to change' },
              'old_text' => { 'type' => 'string', 'description' => 'The exact text to replace' },
              'new_text' => { 'type' => 'string', 'description' => 'The text to put in its place' },
              'replace_all' => { 'type' => %w[boolean null], 'description' => 'Replace every occurrence' }
            },
            'required' => %w[path old_text new_text],
            'additionalProperties' => false
          }
        end

        def execute(path:, old_text:, new_text:, replace_all: false)
          guarded_write do |write|
            path = file_at(path).path
            changing(path) do |file|
              raise ToolError, "There is no file at #{path}." unless file

              replace(file, write, old_text.to_s, new_text.to_s, replace_all)
            end
          end
        end

        private

        def replace(file, write, old_text, new_text, replace_all)
          content = text_of(file)
          count = old_text.empty? ? 0 : content.scan(old_text).size
          raise ToolError, "old_text does not appear in #{file.path}." if count.zero?
          if count > 1 && !replace_all
            raise ToolError, "old_text appears #{count} times in #{file.path}. Add the text around it to make " \
                             'it unique, or set replace_all.'
          end

          write.call(file.path, content.public_send(replace_all ? :gsub : :sub, old_text) { new_text })
          "Replaced #{count} #{count == 1 ? 'occurrence' : 'occurrences'} in #{file.path}."
        end

        def text_of(file)
          content = store.read(file.path).dup.force_encoding(Encoding::UTF_8)
          return content if content.valid_encoding? && !content.include?("\0")

          raise ToolError, "#{file.path} is not a text file, so edit_file cannot change it."
        end
      end
    end
  end
end
