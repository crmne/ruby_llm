# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Image generation methods for the OpenAI API integration
      module Images
        module_function

        def images_url(with: nil, mask: nil)
          editing?(with, mask) ? 'images/edits' : 'images/generations'
        end

        def render_image_payload(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Metrics/ParameterLists
          return render_edit_payload(prompt, model:, with:, mask:, params:) if editing?(with, mask)

          {
            model: model,
            prompt: prompt,
            n: 1,
            size: size
          }.merge(params)
        end

        def parse_image_response(response, model:)
          data = response.body
          image_data = Array(data['data']).first

          raise Error.new(nil, 'Unexpected response format from OpenAI image API') unless image_data

          Image.new(
            url: image_data['url'],
            mime_type: 'image/png', # DALL-E typically returns PNGs
            revised_prompt: image_data['revised_prompt'],
            model_id: model,
            data: image_data['b64_json'],
            usage: data['usage'] || {}
          )
        end

        def validate_paint_inputs!(with:, mask:)
          return unless editing?(with, mask)

          raise ArgumentError, 'with: is required when mask: is provided' if mask && !attachments?(with)
        end

        def render_edit_payload(prompt, model:, with:, mask:, params:)
          payload = params.merge(
            model: model,
            prompt: prompt,
            image: build_upload_parts(with, label: 'images'),
            n: 1
          )
          payload[:mask] = build_upload_part(mask, label: 'mask') if mask
          payload
        end

        def build_upload_parts(sources, label:)
          Array(sources).filter_map do |source|
            next if blank_attachment?(source)

            build_upload_part(source, label:)
          end
        end

        def build_upload_part(source, label:)
          attachment = Attachment.new(source)
          unless attachment.image?
            raise UnsupportedAttachmentError,
                  "OpenAI image editing only supports image attachments for #{label}"
          end

          Faraday::UploadIO.new(StringIO.new(attachment.content), attachment.mime_type, attachment.filename)
        end

        def editing?(with, mask)
          attachments?(with) || !mask.nil?
        end

        def attachments?(value)
          Array(value).any? { |item| !blank_attachment?(item) }
        end

        def blank_attachment?(value)
          value.nil? || (value.is_a?(String) && value.strip.empty?)
        end
      end
    end
  end
end
