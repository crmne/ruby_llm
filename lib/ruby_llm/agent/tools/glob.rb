# frozen_string_literal: true

module RubyLLM
  class Agent
    module Tools
      # Find files by pattern
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Glob)
      #   chat.ask "Find all Ruby files in the lib directory"
      class Glob < RubyLLM::Tool
        description 'Find files matching a glob pattern'

        param :pattern, desc: 'Glob pattern (e.g., "**/*.rb", "lib/**/*_test.rb")'
        param :path, desc: 'Base directory to search in (default: current directory)', required: false

        def execute(pattern:, path: nil)
          base = path ? File.expand_path(path) : Dir.pwd

          unless File.directory?(base)
            return { error: "Directory not found: #{base}" }
          end

          full_pattern = File.join(base, pattern)
          files = Dir.glob(full_pattern).sort

          if files.empty?
            "No files found matching: #{pattern}"
          else
            files.map { |f| f.sub("#{base}/", '') }.join("\n")
          end
        rescue StandardError => e
          { error: e.message }
        end
      end
    end
  end
end
