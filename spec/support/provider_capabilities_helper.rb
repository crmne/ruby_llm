# frozen_string_literal: true

module ProviderCapabilitiesHelper
  def provider_supports_functions?(provider, model)
    provider_class = RubyLLM::Provider.providers[provider]
    
    # Check if the provider class has a supports_functions? method
    if provider_class&.respond_to?(:supports_functions?)
      # Use the provider's class method if available
      provider_class.supports_functions?(model)
    elsif provider_class&.respond_to?(:capabilities)
      # Check the provider's capabilities module
      capabilities = provider_class.capabilities
      if capabilities&.respond_to?(:supports_functions?)
        capabilities.supports_functions?(model)
      else
        # Default to true if no explicit capability defined
        true
      end
    elsif provider_class&.local?
      # For local providers without explicit support method, assume false
      # (they should implement supports_functions? if they support it)
      false
    else
      # For remote providers, check the model registry
      model_info = RubyLLM.models.find(model)
      model_info&.supports_functions? || false
    end
  end
end

RSpec.configure do |config|
  config.include ProviderCapabilitiesHelper
end