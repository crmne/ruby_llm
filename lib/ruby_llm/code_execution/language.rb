# frozen_string_literal: true

module RubyLLM
  class CodeExecution
    class Language < Data.define(:name, :label, :filename, :program, :check) # :nodoc:
      def self.[](name)
        ALL.fetch(name)
      end

      def command(path)
        [program, path]
      end

      def check_command
        [program, *check]
      end

      ALL = {
        ruby: new(name: :ruby, label: 'Ruby', filename: 'main.rb', program: 'ruby', check: ['-e', 'exit']),
        python: new(name: :python, label: 'Python', filename: 'main.py', program: 'python3', check: ['-c', 'pass']),
        shell: new(name: :shell, label: 'shell', filename: 'main.sh', program: 'sh', check: ['-c', 'exit 0'])
      }.freeze
    end
  end
end
