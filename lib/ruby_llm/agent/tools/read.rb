# frozen_string_literal: true

module RubyLLM
  class Agent
    module Tools
      # Read file contents
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Read)
      #   chat.ask "What's in config/routes.rb?"
      class Read < RubyLLM::Tool
        description 'Read the contents of a file from the filesystem'

        param :path, desc: 'Absolute or relative path to the file'
        param :offset, type: 'integer', desc: 'Line number to start reading from (1-indexed)', required: false
        param :limit, type: 'integer', desc: 'Maximum number of lines to read', required: false

        def execute(path:, offset: nil, limit: nil)
          expanded = File.expand_path(path)

          unless File.exist?(expanded)
            return { error: "File not found: #{path}" }
          end

          unless File.readable?(expanded)
            return { error: "File not readable: #{path}" }
          end

          if File.directory?(expanded)
            return { error: "Path is a directory, not a file: #{path}" }
          end

          lines = File.readlines(expanded)

          # Apply offset and limit
          start_line = [(offset || 1) - 1, 0].max
          end_line = limit ? start_line + limit : lines.length

          selected = lines[start_line...end_line] || []

          # Format with line numbers
          selected.each_with_index.map do |line, idx|
            line_num = start_line + idx + 1
            "#{line_num.to_s.rjust(6)}  #{line}"
          end.join
        rescue StandardError => e
          { error: e.message }
        end
      end
    end
  end
end
