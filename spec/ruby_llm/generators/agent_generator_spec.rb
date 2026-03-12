# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/agent/agent_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::AgentGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_agent_generator' }
  let(:app_path) { File.join(Dir.tmpdir, app_name) }

  def run_rails_generate(*args)
    env = {
      'BUNDLE_GEMFILE' => ENV['BUNDLE_GEMFILE'] || Bundler.default_gemfile.to_s,
      'BUNDLE_IGNORE_CONFIG' => '1',
      'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', 'test')
    }
    command = ['bundle', 'exec', 'rails', 'generate', *args]
    GeneratorTestHelpers.run_command(env, command, chdir: app_path)
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    template_path = File.expand_path('../../fixtures/templates', __dir__)
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_agent_generator'))
    GeneratorTestHelpers.create_test_app('test_agent_generator', template: 'default_models_template.rb',
                                                                 template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_agent_generator'))
  end

  it 'creates an agent class and instructions prompt in the convention path' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:agent', 'Support')
      expect(status.success?).to be(true), output

      expect(File.exist?('app/agents/support_agent.rb')).to be true
      expect(File.exist?('app/prompts/support_agent/instructions.txt.erb')).to be true

      agent_class = File.read('app/agents/support_agent.rb')
      expect(agent_class).to include('class SupportAgent < RubyLLM::Agent')
      expect(agent_class).to include("Change `Chat` to your app's chat model for Rails persistence.")
      expect(agent_class).to include('chat_model Chat')
      expect(agent_class).to include('instructions')
    end
  end
end
