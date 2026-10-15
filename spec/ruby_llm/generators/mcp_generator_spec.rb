# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'generators/ruby_llm/mcp/mcp_generator'
require_relative '../../support/generator_test_helpers'

RSpec.describe RubyLLM::Generators::MCPGenerator, :generator, type: :generator do
  include GeneratorTestHelpers

  let(:template_path) { File.expand_path('../../fixtures/templates', __dir__) }
  let(:app_name) { 'test_mcp_generator' }
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
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_mcp_generator'))
    GeneratorTestHelpers.create_test_app('test_mcp_generator', template: 'default_models_template.rb',
                                                               template_path: template_path)
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    GeneratorTestHelpers.cleanup_test_app(File.join(Dir.tmpdir, 'test_mcp_generator'))
  end

  it 'creates MCP server classes for a URL or a local command' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:mcp', 'Linear', 'https://mcp.linear.app/mcp')
      expect(status.success?).to be(true), output
      run_rails_generate('ruby_llm:mcp', 'Files', '--command', 'npx -y @modelcontextprotocol/server-filesystem .')

      expect(File.read('app/mcp/linear.rb'))
        .to eq("class Linear < RubyLLM::MCP\n  url \"https://mcp.linear.app/mcp\"\nend\n")
      expect(File.read('app/mcp/files.rb')).to include(
        'command "npx", "-y", "@modelcontextprotocol/server-filesystem", "."'
      )
      success, runner = run_rails_runner('puts Linear.url, Files.command.inspect')
      expect(success).to be(true), runner
      expect(runner).to include("https://mcp.linear.app/mcp\n")
    end
  end

  it 'asks for a URL or a command' do
    within_test_app(app_path) do
      output, status = run_rails_generate('ruby_llm:mcp', 'Nothing')

      expect(status.success?).to be(false)
      expect(output).to include("Pass the server's URL or --command")
    end
  end
end
