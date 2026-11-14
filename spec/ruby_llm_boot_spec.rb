# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'requiring ruby_llm', type: :task do
  def constant_defined?(constant, after: nil)
    script = ["require 'ruby_llm'", after, "print defined?(#{constant}) ? 'yes' : 'no'"].compact.join('; ')
    output, = Open3.capture2(RbConfig.ruby, '-I', File.expand_path('../lib', __dir__), '-e', script)
    output
  end

  it 'leaves the MIME table unloaded' do
    expect(constant_defined?('Marcel')).to eq('no')
  end

  it 'loads the MIME table with the helper that reads it' do
    expect(constant_defined?('Marcel', after: 'RubyLLM::Files::MimeType')).to eq('yes')
  end

  it 'loads the MIME table with the MCP content reader' do
    expect(constant_defined?('Marcel', after: 'RubyLLM::MCP::Content')).to eq('yes')
  end

  # Zeitwerk declares an autoload for every provider as soon as it sets up,
  # so defined? reports "constant" for all of them whether or not their file
  # has actually run; Module#autoload? instead returns nil once it has.
  def provider_loaded?(name, after: nil)
    script = ["require 'ruby_llm'", after, "print RubyLLM::Providers.autoload?(:#{name}) ? 'no' : 'yes'"]
             .compact.join('; ')
    output, = Open3.capture2(RbConfig.ruby, '-I', File.expand_path('../lib', __dir__), '-e', script)
    output
  end

  it 'leaves every provider unloaded' do
    expect(provider_loaded?('OpenAI')).to eq('no')
    expect(provider_loaded?('Anthropic')).to eq('no')
  end

  it 'loads only the provider a configured setting belongs to' do
    after = "RubyLLM.configure { |config| config.openai_api_key = 'test' }"

    expect(provider_loaded?('OpenAI', after:)).to eq('yes')
    expect(provider_loaded?('Anthropic', after:)).to eq('no')
  end

  it 'resolves an option to the longer of two slugs that share a prefix' do
    after = "RubyLLM.configure { |config| config.ollama_cloud_api_key = 'test' }"

    # OllamaCloud::ChatCompletions subclasses Ollama::ChatCompletions, so
    # Ollama loads too; Anthropic has no such link and stays unloaded,
    # showing the lookup landed on ollama_cloud rather than every provider.
    expect(provider_loaded?('OllamaCloud', after:)).to eq('yes')
    expect(provider_loaded?('Anthropic', after:)).to eq('no')
  end
end
