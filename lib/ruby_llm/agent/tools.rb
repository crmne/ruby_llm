# frozen_string_literal: true

require_relative 'tools/read'
require_relative 'tools/write'
require_relative 'tools/edit'
require_relative 'tools/bash'
require_relative 'tools/glob'
require_relative 'tools/grep'

module RubyLLM
  class Agent
    # Built-in tools for file operations, code editing, and command execution
    module Tools
      # All available built-in tools
      ALL = [Read, Write, Edit, Bash, Glob, Grep].freeze

      # Safe tools that only read (no modifications)
      SAFE = [Read, Glob, Grep].freeze

      # Tools that modify files
      FILE_EDITORS = [Write, Edit].freeze

      # Get tools by category
      #
      # @param category [Symbol] :all, :safe, :file_editors
      # @return [Array<Class>]
      def self.[](category)
        case category
        when :all then ALL
        when :safe then SAFE
        when :file_editors then FILE_EDITORS
        else []
        end
      end
    end
  end
end
