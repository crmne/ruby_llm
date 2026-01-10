# frozen_string_literal: true

module RubyLLM
  class Agent
    module Tools
      # Edit a file by replacing text
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Edit)
      #   chat.ask "Change the function name from 'foo' to 'bar' in lib/my_file.rb"
      class Edit < RubyLLM::Tool
        description 'Edit a file by replacing an exact string match with new content'

        param :path, desc: 'Absolute or relative path to the file'
        param :old_string, desc: 'The exact text to find and replace (must match exactly)'
        param :new_string, desc: 'The text to replace it with'
        param :replace_all, type: 'boolean', desc: 'Replace all occurrences (default: false)', required: false

        def execute(path:, old_string:, new_string:, replace_all: false)
          expanded = File.expand_path(path)

          unless File.exist?(expanded)
            return { error: "File not found: #{path}" }
          end

          content = File.read(expanded)

          unless content.include?(old_string)
            return { error: "String not found in file. Make sure old_string matches exactly." }
          end

          # Check for uniqueness unless replace_all
          if !replace_all && content.scan(old_string).length > 1
            return { error: "Multiple matches found. Provide more context in old_string or use replace_all: true" }
          end

          new_content = if replace_all
                          content.gsub(old_string, new_string)
                        else
                          content.sub(old_string, new_string)
                        end

          File.write(expanded, new_content)

          "Successfully edited #{path}"
        rescue StandardError => e
          { error: e.message }
        end
      end
    end
  end
end
