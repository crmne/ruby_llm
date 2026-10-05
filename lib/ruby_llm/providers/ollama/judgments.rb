# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Ollama's dialect of the System One API, which accepts images for multimodal decision models.
      module Judgments
        module_function

        def judgment_url
          'systemone'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          images = with.map do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

            attachment.encoded
          end
          payload = super(input, questions:, model:, provider_options:)
          images.empty? ? payload : payload.merge(images:)
        end
      end
    end
  end
end
