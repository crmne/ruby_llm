# frozen_string_literal: true

module RubyLLM
  class Evaluation
    # Adds dataset cases as examples when extended by an RSpec example group.
    #
    #   RSpec.describe SupportEvaluation do
    #     extend RubyLLM::Evaluation::RSpec
    #     evaluates described_class
    #   end
    module RSpec
      # Defines one example per case, using the same runner and failure report as Evaluation.run.
      def evaluates(evaluation, dataset: nil, only: nil, **options)
        evaluation.cases(dataset:, only:).each do |test_case|
          it("#{evaluation.name}: #{test_case.name}") do
            report = evaluation.run(dataset: [test_case], **options)
            expect(report).to be_passed, report.to_s
          end
        end
      end
    end
  end
end
