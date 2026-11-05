# frozen_string_literal: true

namespace :conformance do
  desc 'Run the official MCP client conformance suite against RubyLLM::MCP (SCENARIO=name for one)'
  task :mcp do
    directory = File.expand_path('../conformance/mcp', __dir__)
    command = ['npx', '--yes', '@modelcontextprotocol/conformance@0.2.0-alpha.11', 'client',
               '--command', "ruby #{File.join(directory, 'client.rb')}",
               '--expected-failures', File.join(directory, 'expected_failures.yml')]
    command += ENV['SCENARIO'] ? ['--scenario', ENV['SCENARIO']] : ['--suite', 'all']
    sh(*command)
  end
end
