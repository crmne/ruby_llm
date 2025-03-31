# frozen_string_literal: true

require 'json'

# lib/tasks/providers.rake

# frozen_string_literal: true

require 'json'

def missing_provider_methods
  # Ensure the entire codebase is loaded
  require_relative '../../lib/ruby_llm'

  provider_classes = {}
  all_methods = []

  # Collect all public methods from each provider class
  RubyLLM::Providers.constants.each do |provider|
    provider_module = RubyLLM::Providers.const_get(provider)
    next unless provider_module.const_defined?(:Capabilities)

    capabilities_class = provider_module::Capabilities
    methods = capabilities_class.public_methods(false)
    provider_classes[provider] = methods
    all_methods.concat(methods)
  end

  all_methods.uniq!

  # Find methods that are present in all providers
  missing_methods = all_methods.reject do |method|
    provider_classes.values.all? { |methods| methods.include?(method) }
  end

  missing_methods_hash = missing_methods.each_with_object({}) do |method, mms_hash |
    mms_hash[method] = provider_classes.keys.each_with_object({}) do |provider, mm_hash|
      mm_hash[provider] = provider_classes[provider].include?(method)
    end
  end

  missing_methods_hash
end

namespace :providers do
  desc "Check method consistency across providers and output as JSON"
  task :missing_methods_as_json do
    puts JSON.pretty_generate(missing_provider_methods)
  end

  desc "Check method consistency across providers and output as Markdown"
  task :missing_methods_as_markdown do
    puts JSON.pretty_generate(missing_provider_methods)
  end
end