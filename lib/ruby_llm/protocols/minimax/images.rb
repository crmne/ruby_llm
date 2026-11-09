# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # Image generation on v1/image_generation. Source images become
      # subject references, which keep a person's likeness in a new scene;
      # there is no mask.
      module Images
        def images_url(**)
          media_url('v1/image_generation')
        end

        def render_image_payload(prompt, model:, size: nil, count: nil, with: nil, provider_options: {}, **)
          payload = { model: model, prompt: prompt, n: count, response_format: 'base64' }.compact
          payload.merge!(image_dimensions(size))
          references = subject_references(with)
          payload[:subject_reference] = references unless references.empty?
          payload.merge(provider_options)
        end

        def parse_image_responses(response, model:)
          data = response.body['data'] || {}
          sources = Array(data['image_base64']).map { |image| { data: image } } +
                    Array(data['image_urls']).map { |url| { url: } }
          raise Error.new('MiniMax did not return an image', response:) if sources.empty?

          sources.map { |source| Image.new(**source, mime_type: 'image/jpeg', model:) }
        end

        private

        def validate_paint_inputs!(mask:, **)
          raise UnsupportedAttachmentError, 'image mask' if mask
        end

        def image_dimensions(size)
          return {} unless size

          dimensions = size.to_s.match(/\A(\d+)x(\d+)\z/)
          return { aspect_ratio: size.to_s } unless dimensions

          { width: dimensions[1].to_i, height: dimensions[2].to_i }
        end

        def subject_references(sources)
          Attachment.wrap(sources, config: @config).map do |attachment|
            { type: 'character', image_file: attachment.url_or_data_uri }
          end
        end
      end
    end
  end
end
