# frozen_string_literal: true

require 'rails_helper'
require 'tasks/ruby_llm/evaluations'

RSpec.describe RubyLLM::Tasks::Evaluations do
  it "names evaluation classes with the application's acronym inflections" do
    inflections = ActiveSupport::Inflector.inflections.dup
    inflections.acronym('API')
    allow(ActiveSupport::Inflector).to receive(:inflections).and_return(inflections)

    Dir.mktmpdir do |directory|
      allow(RubyLLM::Prompt).to receive(:root).and_return(Pathname.new(directory).join('app/prompts'))
      file = Pathname.new(directory).join('app/evals/checks/support_api_evaluation.rb')
      FileUtils.mkdir_p(file.dirname)
      FileUtils.touch(file)

      expect(described_class.discover('Checks::SupportAPIEvaluation')).to eq(file => 'Checks::SupportAPIEvaluation')
    end
  end
end
