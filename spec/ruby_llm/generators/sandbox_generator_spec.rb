# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/sandbox/sandbox_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::SandboxGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_sandbox_generator' }
  let(:app_path) { GeneratorTestHelpers.app_path(app_name) }

  def run_rails_generate(*args)
    run_rails('generate', *args)
  end

  def run_rails_destroy(*args)
    run_rails('destroy', *args)
  end

  def run_rails(*args)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    GeneratorTestHelpers.run_command(env, ['bundle', 'exec', 'rails', *args], chdir: app_path)
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    template_path = File.expand_path('../../fixtures/templates', __dir__)
    GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path('test_sandbox_generator'))
    GeneratorTestHelpers.create_test_app('test_sandbox_generator', template: 'default_models_template.rb',
                                                                   template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(GeneratorTestHelpers.app_path('test_sandbox_generator'))
  end

  it 'creates a sandbox class in app/sandboxes that RubyLLM can run' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:sandbox', 'Workspace')
      expect(status.success?).to be(true), output

      expect(File.read('app/sandboxes/workspace_sandbox.rb'))
        .to eq("class WorkspaceSandbox < MXC::Sandbox\n  timeout 120\nend\n")
      expect(File.read('Gemfile')).to match(/^gem "mxc", ">= 0.4.1"$/)
      expect(File.read('config/initializers/ruby_llm.rb')).to include('config.sandbox = "WorkspaceSandbox"')
      success, runner = run_rails_runner('require "mxc"; puts RubyLLM::Sandbox.resolve("WorkspaceSandbox").timeout')
      expect(success).to be(true), runner
      expect(runner).to include("120\n")

      output, status = run_rails_generate('ruby_llm:sandbox', 'Online')
      expect(status.success?).to be(true), output
      expect(File.read('config/initializers/ruby_llm.rb')).not_to include('OnlineSandbox')

      output, status = run_rails_destroy('ruby_llm:sandbox', 'Workspace')
      expect(status.success?).to be(true), output
      expect(File.read('config/initializers/ruby_llm.rb')).not_to include('config.sandbox')
      FileUtils.rm_f('app/sandboxes/online_sandbox.rb')
    end
  end

  it 'targets the configure block and keeps a conditional default' do
    within_test_app(app_path) do
      path = 'config/initializers/ruby_llm.rb'
      original = File.read(path)
      File.write(path, "#{original}\nRails.application.config.to_prepare do\n  nil\nend\n# the end\n")
      output, status = run_rails_generate('ruby_llm:sandbox', 'First')
      expect(status.success?).to be(true), output
      expect(File.read(path)).to match(/configure do \|config\|\n  config\.sandbox = "FirstSandbox"\n/)

      File.write(path, %(RubyLLM.configure do |config|\n  config.sandbox ||= "FirstSandbox"\nend\n))
      output, status = run_rails_generate('ruby_llm:sandbox', 'Second')
      expect(status.success?).to be(true), output
      expect(File.read(path)).not_to include('SecondSandbox')
    ensure
      File.write(path, original)
      FileUtils.rm_f(%w[app/sandboxes/first_sandbox.rb app/sandboxes/second_sandbox.rb])
    end
  end

  it 'warns about a Gemfile line that excludes the mxc it needs' do
    within_test_app(app_path) do
      original = File.read('Gemfile')
      initializer = File.read('config/initializers/ruby_llm.rb')
      File.write('Gemfile', %(#{original.gsub(/^gem "mxc".*\n/, '')}\ngem "mxc", "~> 0.3.0", require: false\n))
      output, = run_rails_generate('ruby_llm:sandbox', 'Third')
      expect(output).to include('Change the mxc requirement in your Gemfile to ">= 0.4.1"')
    ensure
      File.write('Gemfile', original)
      File.write('config/initializers/ruby_llm.rb', initializer)
      FileUtils.rm_f('app/sandboxes/third_sandbox.rb')
    end
  end
end
