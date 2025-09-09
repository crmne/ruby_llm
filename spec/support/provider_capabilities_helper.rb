# frozen_string_literal: true

module ProviderCapabilitiesHelper
  def provider_supports_functions?(provider, _model)
    RubyLLM::Provider.providers[provider]

    # Special case for providers we know don't support functions
    return false if %i[red_candle perplexity].include?(provider)

    # For all other providers, assume they support functions
    # The original tests weren't skipping these, so they must have been running
    true
  end
end

RSpec.configure do |config|
  config.include ProviderCapabilitiesHelper
end
