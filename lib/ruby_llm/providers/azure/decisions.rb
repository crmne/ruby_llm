# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure < Provider
      # Azure's dialect of OpenAI Decisions, served from the openai/v1 base.
      # The model field carries the deployment name, as on Responses. The v1
      # routes accept only the v1 and preview API versions, so the request
      # names v1 over any dated version the configured base carries.
      class Decisions < Protocols::OpenAI::Decisions
        def judgment_url
          "#{@provider.azure_openai_v1_base.sub(%r{/+\z}, '')}/decisions?api-version=v1"
        end
      end
    end
  end
end
