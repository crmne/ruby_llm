# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/judge/judge_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::JudgeGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_judge_generator' }
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
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_judge_generator'))
    GeneratorTestHelpers.create_test_app('test_judge_generator', template: 'default_models_template.rb',
                                                                 template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_judge_generator'))
  end

  it 'creates a judge class in app/judges' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:judge', 'Urgency')
      expect(status.success?).to be(true), output

      expect(File.read('app/judges/urgency_judge.rb')).to eq("class UrgencyJudge < RubyLLM::Judge\nend\n")
      success, runner = run_rails_runner('puts UrgencyJudge.superclass')
      expect(success).to be(true), runner
      expect(runner).to include("RubyLLM::Judge\n")
    end
  end
end
