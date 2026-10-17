# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/skill/skill_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::SkillGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_skill_generator' }
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
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_skill_generator'))
    GeneratorTestHelpers.create_test_app('test_skill_generator', template: 'default_models_template.rb',
                                                                 template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_skill_generator'))
  end

  it 'creates a skill folder that loads' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:skill', 'invoices', 'Bills an order to a customer as a PDF.')
      expect(status.success?).to be(true), output

      expect(File.read('app/skills/invoices/SKILL.md'))
        .to eq("---\nname: invoices\ndescription: \"Bills an order to a customer as a PDF.\"\n---\n")
      success, runner = run_rails_runner('puts RubyLLM::Skill.resolve([:invoices]).first.description')
      expect(success).to be(true), runner
      expect(runner).to include("Bills an order to a customer as a PDF.\n")
    end
  end

  it 'refuses a name the Agent Skills format does not allow' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:skill', 'Invoices', 'Bills orders.')

      expect(status.success?).to be(false)
      expect(output).to include('must be lowercase')
      expect(Dir.glob('*', base: 'app/skills')).not_to include('Invoices')
    end
  end
end
