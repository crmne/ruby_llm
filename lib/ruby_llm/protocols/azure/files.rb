# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Azure
      # Azure OpenAI exposes the OpenAI Files API under /openai/v1.
      class Files < Protocols::OpenAI::Files
        private

        def files_url
          "#{@provider.azure_openai_v1_base}/files"
        end
      end
    end
  end
end
