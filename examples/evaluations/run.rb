# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_llm'
require 'fileutils'
require_relative 'app/evals/answer_evaluation'
require_relative 'app/evals/tool_selection_evaluation'

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.typesafe_api_key = ENV.fetch('TYPESAFE_API_KEY', nil)
end

Dir.chdir(__dir__) do
  FileUtils.mkdir_p('tmp')
  report = ToolSelectionEvaluation.run
  puts report
  report.save('tmp/tool_selection.json')

  if ENV['EVAL_MODEL']
    AnswerEvaluation.evaluator(model: ENV.fetch('EVAL_MODEL'))
    report = AnswerEvaluation.run
    puts report
    report.save('tmp/answers.json')
  end
end
