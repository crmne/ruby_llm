# frozen_string_literal: true

require 'faraday'
require 'stringio'

module RubyLLM
  module Protocols
    class ChatCompletions
      # Image generation methods for the OpenAI API integration
      module Images
        module_function

        def images_url(with: nil, mask: nil)
          editing?(with, mask) ? 'images/edits' : 'images/generations'
        end

        def render_image_payload(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {})
          return render_edit_payload(prompt, model:, size:, count:, with:, mask:, provider_options:) if editing?(with,
                                                                                                                 mask)

          {
            model: model,
            prompt: prompt,
            n: count || 1,
            size: size
          }.merge(provider_options)
        end

        def parse_image_response(response, model:)
          parse_image_responses(response, model:).first
        end

        def parse_image_responses(response, model:)
          data = response.body
          entries = Array(data['data'])

          raise Error, 'Unexpected response format from OpenAI image API' if entries.empty?

          entries.map.with_index do |image_data, index|
            Image.new(
              url: image_data['url'],
              mime_type: 'image/png', # DALL-E typically returns PNGs
              revised_prompt: image_data['revised_prompt'],
              model: model,
              data: image_data['b64_json'],
              usage: index.zero? ? (data['usage'] || {}) : {}
            )
          end
        end

        def validate_paint_inputs!(with:, mask:)
          return unless editing?(with, mask)

          raise ArgumentError, 'with: is required when mask: is provided' if mask && !attachments?(with)
        end

        def render_edit_payload(prompt, model:, size:, with:, mask:, provider_options:, count: nil)
          payload = { model: model, prompt: prompt, n: count || 1 }
          if json_image_references?(model)
            payload[:images] = build_image_references(with)
            payload[:mask] = build_image_reference(mask) if mask
            payload[:size] = size if flexible_size?(model) && size
          else
            payload[:image] = single_upload_part(build_upload_parts(with))
            payload[:mask] = build_upload_part(mask) if mask
          end
          payload.merge(provider_options)
        end

        def json_image_references?(model)
          model.match?(/\A(gpt-image|chatgpt-image)/)
        end

        def flexible_size?(model)
          model.include?('gpt-image-2')
        end

        def build_image_references(sources)
          Array(sources).filter_map do |source|
            next if blank_attachment?(source)

            build_image_reference(source)
          end
        end

        def build_image_reference(source)
          attachment = Attachment.new(source, config: @config)
          return { file_id: attachment.provider_file_id } if attachment.provider_file?
          return { image_url: attachment.source.to_s } if attachment.url?

          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

          { image_url: attachment.for_llm }
        end

        def build_upload_parts(sources)
          Array(sources).filter_map do |source|
            next if blank_attachment?(source)

            build_upload_part(source)
          end
        end

        # Retries only rewind upload parts at the top level of the payload,
        # so a lone image rides there instead of inside an array.
        def single_upload_part(parts)
          parts.one? ? parts.first : parts
        end

        def build_upload_part(source)
          attachment = Attachment.new(source, config: @config)
          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

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
