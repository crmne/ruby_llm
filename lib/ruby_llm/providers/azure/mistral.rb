# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure < Provider
      # Azure's Chat Completions plus Mistral's document models on Foundry,
      # which read Mistral's OCR request at a route under the resource root.
      class Mistral < Azure::ChatCompletions
        include Providers::Mistral::OCR

        def ocr_url
          "#{@provider.azure_base_parts[:root]}/providers/mistral/azure/ocr"
        end
      end
    end
  end
end
