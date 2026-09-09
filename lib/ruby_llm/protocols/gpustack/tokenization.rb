# frozen_string_literal: true

module RubyLLM
  module Protocols
    module GPUStack
      # vLLM's text tokenizer through GPUStack's model proxy.
      module Tokenization
        def tokenization_url
          "#{@provider.backend_api_base}/tokenize"
        end

        def render_tokenization_payload(text, model:)
          { model: model, prompt: text }
        end

        def parse_tokenization_response(response, model:)
          RubyLLM::Tokenization.new(ids: response.body.fetch('tokens'), model: model, raw: response.body)
        end
      end
    end
  end
end
