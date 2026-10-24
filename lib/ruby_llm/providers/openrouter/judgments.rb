# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # OpenRouter's dialect of the System One API: the Decisions route, media
      # parts inside the state, and the exact cost of each judgment.
      module Judgments
        module_function

        def judgment_url
          '../alpha/decisions'
        end

        def render_judgment_payload(input, questions:, model:, with: [], provider_options: {})
          parts = with.map { |attachment| render_judgment_part(attachment) }
          super(render_judgment_state(input, parts), questions:, model:, provider_options:)
        end

        def render_judgment_state(input, parts)
          return input if parts.empty?
          return parts if input.nil?

          input.is_a?(Array) ? input + parts : [input, *parts]
        end

        def render_judgment_part(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type if attachment.provider_file?

          case attachment.type
          when :image
            Protocols::ChatCompletions::Media.with_image_detail(
              { type: 'image_url', image_url: { url: attachment.for_llm } }, attachment
            )
          when :audio then Protocols::ChatCompletions::Media.render_audio(attachment)
          when :video then { type: 'video_url', video_url: { url: attachment.for_llm } }
          else raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def reported_cost(usage)
          usage['cost']
        end
      end
    end
  end
end
