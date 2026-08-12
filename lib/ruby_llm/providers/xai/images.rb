# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Image generation and editing for the xAI API. Generation rejects the
      # size parameter. Editing takes JSON image references (URL, data URI,
      # or file id) instead of multipart uploads, up to three per request,
      # and has no mask support.
      module Images
        module_function

        def images_url(with: nil, mask: nil)
          editing?(with, mask) ? 'images/edits' : 'images/generations'
        end

        def render_image_payload(prompt, model:, size:, n: nil, with: nil, mask: nil, provider_options: {})
          return render_edit_payload(prompt, model:, n:, with:, provider_options:) if editing?(with, mask)

          RubyLLM.logger.debug { "Ignoring size #{size}. xAI image generation does not support a size parameter." }
          payload = { model: model, prompt: prompt }
          payload[:n] = n if n

          payload.merge(provider_options)
        end

        def render_edit_payload(prompt, model:, with:, provider_options:, n: nil)
          payload = {
            model: model,
            prompt: prompt,
            images: image_references(with)
          }
          payload[:n] = n if n

          payload.merge(provider_options)
        end

        def image_references(sources)
          Array(sources).filter_map do |source|
            next if blank_attachment?(source)

            { type: 'image_url', url: image_reference_url(source) }
          end
        end

        def image_reference_url(source)
          attachment = Attachment.new(source)
          return attachment.provider_file_id if attachment.provider_file?
          return attachment.source.to_s if attachment.url?

          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

          attachment.for_llm
        end

        def parse_image_response(response, model:)
          parse_image_responses(response, model:).first
        end

        def parse_image_responses(response, model:)
          data = response.body
          entries = Array(data['data'])

          raise Error, 'Unexpected response format from xAI image API' if entries.empty?

          entries.map.with_index do |image_data, index|
            Image.new(
              url: image_data['url'],
              data: image_data['b64_json'],
              mime_type: image_data['mime_type'] || 'image/png',
              model: model,
              usage: index.zero? ? (data['usage'] || {}) : {}
            )
          end
        end

        def validate_paint_inputs!(with:, mask:) # rubocop:disable Lint/UnusedMethodArgument
          raise Error, 'xAI image editing does not support a mask parameter' if mask
        end

        def editing?(with, mask)
          Protocols::ChatCompletions::Images.editing?(with, mask)
        end

        def blank_attachment?(value)
          Protocols::ChatCompletions::Images.blank_attachment?(value)
        end
      end
    end
  end
end
