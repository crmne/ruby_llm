# frozen_string_literal: true

require_relative 'lib/ruby_llm/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_llm'
  spec.version       = RubyLLM::VERSION
  spec.authors       = ['Carmine Paolino']
  spec.email         = ['carmine@paolino.me']

  spec.summary       = 'Build AI features the Ruby way: a delightful Ruby AI framework for every major AI provider.'
  spec.description   = 'Build AI features the Ruby way. A delightful Ruby AI framework that feels at home in ' \
                       'Rails: switch models without rewriting your code, then scale from a single call to ' \
                       'production agents, RAG, and workflows. Features chat (text, images, audio, PDFs), ' \
                       'image generation, embeddings, tools (function calling), structured output, Rails ' \
                       'integration, and streaming. Works with OpenAI, Azure, Anthropic, Google Gemini, ' \
                       'Vertex AI, AWS Bedrock, xAI, Cohere, DeepSeek, Mistral, Perplexity, OpenRouter, ' \
                       'ElevenLabs, Deepgram, Ollama and GPUStack (local models), and any OpenAI-compatible ' \
                       'API. Plain Ruby with a small set of runtime dependencies.'

  spec.homepage      = 'https://rubyllm.com'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.3')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/crmne/ruby_llm'
  spec.metadata['changelog_uri'] = "#{spec.metadata['source_code_uri']}/releases"
  spec.metadata['documentation_uri'] = 'https://rubyllm.com/next/'
  spec.metadata['bug_tracker_uri'] = "#{spec.metadata['source_code_uri']}/issues"
  spec.metadata['funding_uri'] = 'https://github.com/sponsors/crmne'

  spec.metadata['rubygems_mfa_required'] = 'true'

  # Post-install message for upgrading users
  spec.post_install_message = <<~MESSAGE
    RubyLLM 2.0 release candidate 1

      2.0 renames several APIs and changes what message content returns. Coming
      from 1.x? Read the upgrade guide before you boot:

        https://rubyllm.com/next/upgrading/

      The Rails upgrade uses forward-only preparation, backfill, and finish
      phases, with cleanup later. Rename mode is the default; optional copy
      mode supports a controlled return to 1.16. Read its requirements in the
      upgrade guide and rehearse on a recent production snapshot.

      Agent skill: https://rubyllm.com/next/ai-coding-assistants/
  MESSAGE

  spec.files = Dir.glob('{lib,skills}/**/*') + Dir.glob('exe/*') + ['README.md', 'LICENSE', '.rdoc_options']
  spec.bindir = 'exe'
  spec.executables = ['ruby_llm']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'base64'
  spec.add_dependency 'event_stream_parser', '~> 1'
  spec.add_dependency 'faraday', ENV['FARADAY_VERSION'] || '>= 1.10.0'
  spec.add_dependency 'faraday-multipart', '>= 1'
  spec.add_dependency 'faraday-net_http', '>= 1'
  spec.add_dependency 'faraday-retry', '>= 1'
  spec.add_dependency 'marcel', '>= 1.0', '< 3'
  spec.add_dependency 'schematist', '~> 1.1'
  spec.add_dependency 'zeitwerk', '~> 2'
end
