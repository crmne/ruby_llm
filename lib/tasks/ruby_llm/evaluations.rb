# frozen_string_literal: true

require 'fileutils'

module RubyLLM
  module Tasks
    module Evaluations # :nodoc:
      module_function

      def run(name = nil, only: nil)
        files = discover(name)
        repetitions = Integer(ENV.fetch('EVAL_REPETITIONS', '1'))
        reports = files.map do |file, class_name|
          require file.to_s
          evaluation = Object.const_get(class_name)
          raise ArgumentError, "#{class_name} must inherit from RubyLLM::Evaluation" unless evaluation < Evaluation

          report = evaluation.run(only:, repetitions:)
          path = Pathname.new(ENV.fetch('EVAL_OUTPUT', 'tmp/evaluations')).join("#{class_name.gsub('::', '/')}.json")
          FileUtils.mkdir_p(path.dirname)
          report.save(path)
          puts report
          puts "Report: #{path}"
          report
        end
        abort 'Evaluations failed' unless reports.all?(&:passed?)
      end

      def discover(name)
        root = Prompt.root.parent.join('evals')
        inflector = Zeitwerk::Inflector.new
        files = root.glob('**/*_evaluation.rb').sort.to_h do |file|
          parts = file.relative_path_from(root).to_s.delete_suffix('.rb').split('/')
          [file, parts.map { |part| inflector.camelize(part, file.to_s) }.join('::')]
        end
        files.select! { |_file, class_name| class_name == name } if name
        raise ArgumentError, "No evaluations found in #{root}#{" matching #{name}" if name}" if files.empty?

        files
      end
    end
  end
end
