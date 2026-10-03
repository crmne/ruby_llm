# frozen_string_literal: true

# Assesses synthetic candidate answers against their reference answers.
class AnswerEvaluation < RubyLLM::Evaluation
  evaluation :correctness,
             'The actual answer answers the question and agrees with the expected output. ' \
             'Accept paraphrases. An incorrect number, contradiction, or missing answer fails.'

  def perform(input)
    input.fetch('answer')
  end

  def assertions
    assert_kind_of String, output
  end
end
