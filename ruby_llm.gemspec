# frozen_string_literal: true

require_relative 'lib/ruby_llm/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_llm'
  spec.version       = RubyLLM::VERSION
  spec.authors       = ['Carmine Paolino']
  spec.email         = ['carmine@paolino.me']

  spec.summary       = 'Beautiful Ruby interface to modern AI'
  spec.description   = 'A delightful Ruby way to work with AI. Chat in text, analyze and generate ' \
                       'images, understand audio, and use tools through a unified interface to ' \
                       'OpenAI, Anthropic, Google, AWS Bedrock Anthropic, and DeepSeek. Built for ' \
                       'developer happiness with automatic token counting, proper streaming, and ' \
                       'Rails integration. No wrapping your head around multiple APIs - just clean ' \
                       'Ruby code that works.'
  spec.homepage      = 'https://rubyllm.com'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/crmne/ruby_llm'
  spec.metadata['changelog_uri'] = "#{spec.metadata['source_code_uri']}/commits/main"
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.metadata['source_code_uri']}/issues"

  spec.metadata['rubygems_mfa_required'] = 'true'

  # Use Dir.glob to list all files within the lib directory
  spec.files = Dir.glob('lib/**/*') + ['README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'base64'
  spec.add_dependency 'event_stream_parser', '~> 1'
  spec.add_dependency 'faraday', '~> 2'
  spec.add_dependency 'faraday-multipart', '~> 1'
  spec.add_dependency 'faraday-net_http', '~> 3'
  spec.add_dependency 'faraday-retry', '~> 2'
  spec.add_dependency 'zeitwerk', '~> 2'
end
