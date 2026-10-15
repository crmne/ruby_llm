# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/sandbox/sandbox_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::SandboxGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_sandbox_generator' }
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
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_sandbox_generator'))
    GeneratorTestHelpers.create_test_app('test_sandbox_generator', template: 'default_models_template.rb',
                                                                   template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_sandbox_generator'))
  end

  it 'creates a sandbox class in app/sandboxes that RubyLLM can run' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:sandbox', 'Workspace')
      expect(status.success?).to be(true), output

      expect(File.read('app/sandboxes/workspace_sandbox.rb'))
        .to eq("class WorkspaceSandbox < MXC::Sandbox\n  timeout 120\nend\n")
      expect(File.read('Gemfile')).to match(/^gem "mxc"$/)
      success, runner = run_rails_runner('require "mxc"; puts RubyLLM::Sandbox.resolve("WorkspaceSandbox").timeout')
      expect(success).to be(true), runner
      expect(runner).to include("120\n")
    end
  end
end
