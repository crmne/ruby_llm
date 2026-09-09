# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # GPUStack's vLLM backend accepts multimodal embeddings as messages.
      module Embeddings
        module_function

        def supports_embedding_media?
          true
        end

        def render_embedding_payload(text, model:, dimensions:, task_type: nil, title: nil, with: [],
                                     provider_options: {})
          payload = super(text, model:, dimensions:, task_type:, title:, provider_options: {})
          if with.any?
            raise ArgumentError, 'embed one text at a time when embedding attachments' if text.is_a?(Array)

            payload.delete(:input)
            payload[:messages] = [{ role: 'user', content: GPUStack::Media.format_content(text, with) }]
          end
          payload.merge(provider_options)
        end
      end
    end
  end
end
