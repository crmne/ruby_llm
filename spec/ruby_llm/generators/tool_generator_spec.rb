# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/tool/tool_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::ToolGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_tool_generator' }
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
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_tool_generator'))
    GeneratorTestHelpers.create_test_app('test_tool_generator', template: 'default_models_template.rb',
                                                                template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_tool_generator'))
  end

  it 'creates a tool class and tool call/result partials' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:tool', 'Weather')
      expect(status.success?).to be(true), output

      expect(File.exist?('app/tools/weather_tool.rb')).to be true
      expect(File.exist?('app/views/messages/tool_calls/_weather.html.erb')).to be true
      expect(File.exist?('app/views/messages/tool_results/_weather.html.erb')).to be true

      tool_class = File.read('app/tools/weather_tool.rb')
      expect(tool_class).to include('class WeatherTool < RubyLLM::Tool')
      expect(tool_class).to include('description "TODO: describe what this tool does"')
      expect(tool_class).to include('def execute')

      tool_call_partial = File.read('app/views/messages/tool_calls/_weather.html.erb')
      expect(tool_call_partial).to include('message: tool_calls')
      expect(tool_call_partial).to include('tool_calls: tool_calls, tool_call: tool_call')

      tool_result_partial = File.read('app/views/messages/tool_results/_weather.html.erb')
      expect(tool_result_partial).to include('render "messages/tool_results/default", tool: tool')
    end
  end
end
