# frozen_string_literal: true

module RubyLLM
  module Providers
    class AzureOpenAI
      # Streaming methods of the Azure OpenAI API integration
      module Streaming
        # Azure OpenAI uses the same streaming implementation as OpenAI.
        # The completion_url override in AzureOpenAI::Chat handles the
        # different endpoint format for Azure deployments.
      end
    end
  end
end
