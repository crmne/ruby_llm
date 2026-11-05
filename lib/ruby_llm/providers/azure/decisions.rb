# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure < Provider
      # Azure's dialect of OpenAI Decisions, served from the implicitly
      # versioned openai/v1 base. The model field carries the deployment
      # name, as on Responses.
      class Decisions < Protocols::OpenAI::Decisions
        def judgment_url
          "#{@provider.azure_openai_v1_base}/decisions"
        end
      end
    end
  end
end
