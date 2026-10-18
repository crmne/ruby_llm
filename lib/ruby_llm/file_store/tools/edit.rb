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
          "Changes a text file in this chat's file store by replacing old_text, which must appear exactly " \
            'once, with new_text. Include enough of the surrounding text to make old_text unique, or set ' \
            'replace_all to replace every occurrence.'
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
          guarded do
            file = file_at(path)
            content = text_of(file)
            count = old_text.to_s.empty? ? 0 : content.scan(old_text.to_s).size
            raise ToolError, "old_text does not appear in #{file.path}." if count.zero?
            if count > 1 && !replace_all
              raise ToolError, "old_text appears #{count} times in #{file.path}. Add the text around it to make " \
                               'it unique, or set replace_all.'
            end

            replace = replace_all ? :gsub : :sub
            write(file.path, content.public_send(replace, old_text.to_s) { new_text.to_s })
            "Replaced #{count} #{count == 1 ? 'occurrence' : 'occurrences'} in #{file.path}."
          end
        end

        private

        def text_of(file)
          content = store.read(file.path).dup.force_encoding(Encoding::UTF_8)
          return content if content.valid_encoding? && !content.include?("\0")

          raise ToolError, "#{file.path} is not a text file, so edit_file cannot change it."
        end
      end
    end
  end
end
