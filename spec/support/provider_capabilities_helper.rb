# frozen_string_literal: true

module ProviderCapabilitiesHelper
  def provider_supports_functions?(provider, model)
    provider_class = RubyLLM::Provider.providers[provider]
    
    # Special case for providers we know don't support functions
    return false if provider == :red_candle || provider == :perplexity
    
    # For all other providers, assume they support functions
    # The original tests weren't skipping these, so they must have been running
    true
  end
end

RSpec.configure do |config|
  config.include ProviderCapabilitiesHelper
end