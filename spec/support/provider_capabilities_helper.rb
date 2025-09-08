# frozen_string_literal: true

module ProviderCapabilitiesHelper
  def provider_supports_functions?(provider, model)
    provider_class = RubyLLM::Provider.providers[provider]
    
    # Special case for providers we know don't support functions
    return false if provider == :red_candle || provider == :perplexity
    
    # For local providers (Ollama, GPUStack), default to true unless the model is known not to support it
    if provider_class&.local?
      # Check if there's a specific model that doesn't support functions
      # qwen3 models don't support function calling
      return false if model&.include?('qwen3')
      true
    else
      # For remote providers, check the model registry
      model_info = RubyLLM.models.find(model)
      # If not in registry, default to true (was running before)
      model_info.nil? ? true : model_info.supports_functions?
    end
  end
end

RSpec.configure do |config|
  config.include ProviderCapabilitiesHelper
end