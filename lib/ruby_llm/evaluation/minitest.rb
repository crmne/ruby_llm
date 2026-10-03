# frozen_string_literal: true

module RubyLLM
  class Evaluation
    # Adds dataset cases as tests when extended by a Minitest or Rails test class.
    #
    #   class SupportTest < Minitest::Test
    #     extend RubyLLM::Evaluation::Minitest
    #     evaluates SupportEvaluation
    #   end
    module Minitest
      # Defines one test per case, using the same runner and failure report as Evaluation.run.
      def evaluates(evaluation, dataset: nil, only: nil, **options)
        evaluation.cases(dataset:, only:).each do |test_case|
          name = "test_#{evaluation.name}: #{test_case.name}"
          raise ArgumentError, "Duplicate evaluation test: #{name}" if method_defined?(name)

          define_method(name) do
            report = evaluation.run(dataset: [test_case], **options)
            assert report.passed?, report.to_s
          end
        end
      end
    end
  end
end
