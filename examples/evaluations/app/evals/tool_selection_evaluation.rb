# frozen_string_literal: true

# Checks tool selection and arguments without executing the requested action.
class ToolSelectionEvaluation < RubyLLM::Evaluation
  def perform(input)
    RubyLLM::ToolCall.new(id: 'candidate', name: input.fetch('name'), arguments: input.fetch('arguments'))
  end

  def assertions
    assert_equal expected_output.fetch('name'), result.name
    assert_equal expected_output.fetch('arguments'), result.arguments
  end
end
