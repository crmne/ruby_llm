# frozen_string_literal: true

module RubyLLM
  class Agent
    module Tools
      # Search file contents
      #
      # Example:
      #   chat.with_tool(RubyLLM::Agent::Tools::Grep)
      #   chat.ask "Find all TODO comments in the codebase"
      class Grep < RubyLLM::Tool
        description 'Search for a pattern in files'

        param :pattern, desc: 'Regular expression pattern to search for'
        param :path, desc: 'File or directory to search in (default: current directory)', required: false
        param :glob, desc: 'File pattern filter (e.g., "*.rb")', required: false

        MAX_RESULTS = 100

        def execute(pattern:, path: nil, glob: nil)
          base = path ? File.expand_path(path) : Dir.pwd
          regex = Regexp.new(pattern, Regexp::IGNORECASE)

          files = if File.file?(base)
                    [base]
                  elsif File.directory?(base)
                    file_pattern = glob || '**/*'
                    Dir.glob(File.join(base, file_pattern)).select { |f| File.file?(f) }
                  else
                    return { error: "Path not found: #{base}" }
                  end

          results = []
          files.each do |file|
            next unless File.readable?(file)
            next if binary?(file)

            File.readlines(file).each_with_index do |line, idx|
              if line.match?(regex)
                relative = file.sub("#{Dir.pwd}/", '')
                results << "#{relative}:#{idx + 1}: #{line.strip}"
                break if results.length >= MAX_RESULTS
              end
            end
            break if results.length >= MAX_RESULTS
          rescue StandardError
            next # Skip unreadable files
          end

          if results.empty?
            "No matches found for: #{pattern}"
          else
            output = results.join("\n")
            output += "\n... (truncated, #{MAX_RESULTS}+ matches)" if results.length >= MAX_RESULTS
            output
          end
        rescue RegexpError => e
          { error: "Invalid regex pattern: #{e.message}" }
        rescue StandardError => e
          { error: e.message }
        end

        private

        def binary?(file)
          # Quick binary check - look for null bytes in first 8KB
          File.open(file, 'rb') { |f| f.read(8192)&.include?("\x00") }
        rescue StandardError
          true
        end
      end
    end
  end
end
