# frozen_string_literal: true

module RubyLLM
  class Agent
    module Tools
      # Write content to a file
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Write)
      #   chat.ask "Create a hello world script at hello.rb"
      class Write < RubyLLM::Tool
        description 'Write content to a file, creating it if it does not exist or overwriting if it does'

        param :path, desc: 'Absolute or relative path to the file'
        param :content, desc: 'Content to write to the file'

        def execute(path:, content:)
          expanded = File.expand_path(path)

          # Create parent directories if needed
          dir = File.dirname(expanded)
          FileUtils.mkdir_p(dir) unless File.exist?(dir)

          File.write(expanded, content)

          "Successfully wrote #{content.bytesize} bytes to #{path}"
        rescue StandardError => e
          { error: e.message }
        end
      end
    end
  end
end
