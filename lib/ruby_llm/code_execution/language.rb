# frozen_string_literal: true

module RubyLLM
  class CodeExecution
    Language = Data.define(:name, :label, :filename, :program, :check) do # :nodoc:
      def self.[](name)
        self::ALL.fetch(name)
      end

      def command(path)
        [program, path]
      end

      def check_command
        [program, *check]
      end
    end

    Language::ALL = {
      ruby: Language.new(name: :ruby, label: 'Ruby', filename: 'main.rb', program: 'ruby', check: ['-e', 'exit']),
      python: Language.new(name: :python, label: 'Python', filename: 'main.py', program: 'python3',
                           check: ['-c', 'pass']),
      javascript: Language.new(name: :javascript, label: 'JavaScript', filename: 'main.js', program: 'node',
                               check: ['-e', '0']),
      shell: Language.new(name: :shell, label: 'shell', filename: 'main.sh', program: 'sh', check: ['-c', 'exit 0'])
    }.freeze
  end
end
