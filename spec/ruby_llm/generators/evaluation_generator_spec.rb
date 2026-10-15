# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/evaluation/evaluation_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::EvaluationGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_evaluation_generator' }
  let(:app_path) { File.join(Dir.tmpdir, app_name) }

  def run_rails_generate(*args)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    GeneratorTestHelpers.run_command(env, ['bundle', 'exec', 'rails', 'generate', *args], chdir: app_path)
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    template_path = File.expand_path('../../fixtures/templates', __dir__)
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_evaluation_generator'))
    GeneratorTestHelpers.create_test_app('test_evaluation_generator', template: 'default_models_template.rb',
                                                                      template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_evaluation_generator'))
  end

  it 'creates an evaluation and a dataset with one case, running the matching agent when there is one' do
    within_test_app(app_path) do
      run_rails_generate('ruby_llm:agent', 'Support')
      output, status = run_rails_generate('ruby_llm:evaluation', 'Support')
      expect(status.success?).to be(true), output
      run_rails_generate('ruby_llm:evaluation', 'Answers')

      expect(File.read('app/evals/support_evaluation.rb')).to include('SupportAgent.new.ask(input)')
      expect(File.read('app/evals/answers_evaluation.rb')).to include('RubyLLM.chat.ask(input)')
      expect(File.read('app/evals/support_evaluation.yml')).to include('- name: first_case')
      success, runner = run_rails_runner('puts SupportEvaluation.cases.map(&:name)')
      expect(success).to be(true), runner
      expect(runner).to include("first_case\n")
    end
  end
end
