# frozen_string_literal: true

require 'open3'

module RubyLLM
  class CodeExecution
    # The Node.js the application's PATH finds, as code execution mounts
    # it: the installation read-only, wherever a version manager put it.
    # Asks +node+ itself for its executable, since a version manager's
    # shim is a different program.
    class NodeInstallation # :nodoc:
      def self.current
        @current ||= new
      end

      def initialize(node: 'node')
        @node = node
      end

      def prefix
        executable && File.dirname(executable, 2)
      end

      def bin_dir
        executable && File.dirname(executable)
      end

      def version
        details&.last
      end

      def readable
        [prefix].compact
      end

      private

      def executable
        details&.first
      end

      def details
        return @details if defined?(@details)

        @details = begin
          output, status = Open3.capture2(@node, '-p', 'process.execPath + "\\n" + process.version',
                                          err: File::NULL)
          lines = output.lines.map(&:chomp)
          status.success? && lines.size == 2 ? [File.realpath(lines.first), lines.last] : nil
        rescue SystemCallError
          nil
        end
      end
    end
  end
end
