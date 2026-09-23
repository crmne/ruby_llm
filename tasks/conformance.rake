# frozen_string_literal: true

desc 'Run the official MCP client conformance suite against RubyLLM::MCP (SCENARIO=name for one)'
task :conformance do
  directory = File.expand_path('../conformance', __dir__)
  command = ['npx', '--yes', '@modelcontextprotocol/conformance@alpha', 'client',
             '--command', "ruby #{File.join(directory, 'client.rb')}",
             '--expected-failures', File.join(directory, 'expected_failures.yml')]
  command += ENV['SCENARIO'] ? ['--scenario', ENV['SCENARIO']] : ['--suite', 'all']
  sh(*command)
end
