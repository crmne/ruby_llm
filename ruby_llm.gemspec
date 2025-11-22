# frozen_string_literal: true

require_relative 'lib/ruby_llm/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_llm'
  spec.version       = RubyLLM::VERSION
  spec.authors       = ['Carmine Paolino']
  spec.email         = ['carmine@paolino.me']

  spec.summary       = 'One beautiful Ruby API for GPT, Claude, Gemini, and more.'
  spec.description   = 'One beautiful Ruby API for GPT, Claude, Gemini, and more. Easily build chatbots, ' \
                       'AI agents, RAG applications, and content generators. Features chat (text, images, audio, ' \
                       'PDFs), image generation, embeddings, tools (function calling), structured output, Rails ' \
                       'integration, and streaming. Works with OpenAI, Anthropic, Google Gemini, AWS Bedrock, ' \
                       'DeepSeek, Mistral, Ollama (local models), OpenRouter, Perplexity, GPUStack, and any ' \
                       'OpenAI-compatible API. Minimal dependencies - just Faraday, Zeitwerk, and Marcel.'

  spec.homepage      = 'https://rubyllm.com'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.3')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/crmne/ruby_llm'
  spec.metadata['changelog_uri'] = "#{spec.metadata['source_code_uri']}/commits/main"
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.metadata['source_code_uri']}/issues"
  spec.metadata['funding_uri'] = 'https://github.com/sponsors/crmne'

  spec.metadata['rubygems_mfa_required'] = 'true'

  # Post-install message for upgrading users
  spec.post_install_message = <<~MESSAGE
    Upgrading from RubyLLM <= 1.8.x? Check the upgrade guide for new features and migration instructions
    --> https://rubyllm.com/upgrading/
  MESSAGE

  # Use Dir.glob to list all files within the lib directory
  spec.files = Dir.glob('lib/**/*') + ['README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'base64'
  spec.add_dependency 'event_stream_parser', '~> 1'
  spec.add_dependency 'faraday', ENV['FARADAY_VERSION'] || '>= 1.10.0'
  spec.add_dependency 'faraday-multipart', '>= 1'
  spec.add_dependency 'faraday-net_http', '>= 1'
  spec.add_dependency 'faraday-retry', '>= 1'
  spec.add_dependency 'marcel', '~> 1.0'
  spec.add_dependency 'ruby_llm-schema', '~> 0.2.1'
  spec.add_dependency 'zeitwerk', '~> 2'
end
