# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Image generation for the xAI API, which rejects the size parameter.
      module Images
        module_function

        def render_image_payload(prompt, model:, size:, with: nil, mask: nil, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          RubyLLM.logger.debug { "Ignoring size #{size}. xAI image generation does not support a size parameter." }
          {
            model: model,
            prompt: prompt
          }.merge(provider_options)
        end
      end
    end
  end
end
