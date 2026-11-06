# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Tools
      # The +edit_file+ tool: replaces exact spans of text files, one or
      # several in a call, all or none.
      class Edit < Base # :nodoc:
        Change = Struct.new(:label, :path, :old_text, :new_text, :replace_all) # :nodoc:

        def self.tool_name
          'edit_file'
        end

        def description
          'Changes text files you have read by replacing old_text, which must appear exactly once, with ' \
            'new_text. A text file attached to the question counts as read, at its file name. Include ' \
            'surrounding text to make old_text unique, or set replace_all. Pass edits for several changes in ' \
            'one call, to one file or several: they apply in order, all or none.'
        end

        def parameters_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => %w[string null], 'description' => 'The file to change' },
              'old_text' => { 'type' => %w[string null], 'description' => 'The exact text to replace' },
              'new_text' => { 'type' => %w[string null], 'description' => 'The text to put in its place' },
              'replace_all' => { 'type' => %w[boolean null], 'description' => 'Replace every occurrence' },
              'edits' => { 'type' => %w[array null], 'description' => 'Several changes; each may name a path',
                           'items' => edit_schema }
            },
            'additionalProperties' => false
          }
        end

        def execute(path: nil, old_text: nil, new_text: nil, replace_all: false, edits: nil)
          guarded_write do |write|
            raise ToolError, 'Pass old_text and new_text, or edits, not both.' if edits && (old_text || new_text)

            changes = changes_for(path, old_text, new_text, replace_all, edits)
            store.with_lock do
              files = apply(changes)
              write_all(files, write) || report(files)
            end
          end
        end

        private

        def edit_schema
          {
            'type' => 'object',
            'properties' => {
              'path' => { 'type' => %w[string null] },
              'old_text' => { 'type' => 'string' },
              'new_text' => { 'type' => 'string' },
              'replace_all' => { 'type' => %w[boolean null] }
            },
            'required' => %w[old_text new_text],
            'additionalProperties' => false
          }
        end

        def changes_for(path, old_text, new_text, replace_all, edits)
          return batch(path, edits) unless edits.nil?
          raise ToolError, 'Pass path.' if path.to_s.strip.empty?

          [Change.new('', path, old_text, new_text, replace_all)]
        end

        def batch(path, edits)
          raise ToolError, 'edits is empty.' if Array(edits).empty?

          Array(edits).each_with_index.map do |edit, index|
            edit = edit.to_h.transform_keys(&:to_s)
            target = edit['path'] || path
            if target.to_s.strip.empty?
              raise ToolError,
                    "Edit #{index + 1} has no path. Pass path, or a path in each edit."
            end

            Change.new("Edit #{index + 1}: ", target, edit['old_text'], edit['new_text'], edit['replace_all'])
          end
        end

        def apply(changes)
          changes.each_with_object({}) do |change, files|
            path = labelled(change) { path_for(change.path) }
            files[path] ||= labelled(change) { [contents(path), 0] }
            content, count = labelled(change) { replace(files[path].first, path, change) }
            files[path] = [content, files[path].last + count]
          end
        end

        # Returns the error once a write fails after others landed, instead
        # of raising, so a store's transaction keeps what the answer reports.
        def write_all(files, write)
          changed = []
          files.each do |path, (content, _count)|
            write.call(path, content)
            changed << path
          end
          nil
        rescue FileStoreFullError, SystemCallError => e
          raise if changed.empty?

          reason = e.is_a?(SystemCallError) ? SystemCallError.new(e.errno).message : e.message
          { error: "#{reason} These files already changed: #{changed.join(', ')}." }
        end

        def labelled(change)
          yield
        rescue ToolError => e
          raise ToolError, "#{change.label}#{e.message}"
        end

        def contents(path)
          file = store[path] || raise(ToolError, "There is no file at #{path}. #{missing_hint(path)}")
          fresh!(file)
          text_of(file)
        end

        def replace(content, path, change)
          raise ToolError, 'Pass new_text, or an empty string to delete old_text.' if change.new_text.nil?

          old_text = change.old_text.to_s
          count = old_text.empty? ? 0 : content.scan(old_text).size
          raise ToolError, "old_text does not appear in #{path}." if count.zero?
          if count > 1 && !change.replace_all
            raise ToolError, "old_text appears #{count} times in #{path}. Add the text around it to make " \
                             'it unique, or set replace_all.'
          end

          [content.public_send(change.replace_all ? :gsub : :sub, old_text) { change.new_text.to_s }, count]
        end

        def report(files)
          count = files.values.sum(&:last)
          replaced = "Replaced #{count} #{count == 1 ? 'occurrence' : 'occurrences'}"
          return "#{replaced} in #{files.keys.first}." if files.one?

          "#{replaced} in #{files.size} files: #{files.keys.join(', ')}."
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
