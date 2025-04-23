# frozen_string_literal: true

require_relative 'lib/ruby_llm/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_llm'
  spec.version       = RubyLLM::VERSION
  spec.authors       = ['Carmine Paolino']
  spec.email         = ['carmine@paolino.me']

  spec.summary       = 'A single delightful Ruby way to work with AI.'
  spec.description   = 'A delightful Ruby way to work with AI. Tired of juggling different SDKs? ' \
                       'RubyLLM provides one beautiful, Ruby-like interface for OpenAI, Anthropic, ' \
                       'Gemini, Bedrock, OpenRouter, DeepSeek, Ollama, and any OpenAI-compatible API. ' \
                       'Chat (with text, images, audio, PDFs), generate images, create embeddings, ' \
                       'use tools (function calling), stream responses, and integrate with Rails ' \
                       'effortlessly. Minimal dependencies, maximum developer happiness - just clean ' \
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
