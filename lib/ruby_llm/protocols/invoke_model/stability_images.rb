# frozen_string_literal: true

module RubyLLM
  module Protocols
    class InvokeModel
      # Stability image generation and inpainting over Bedrock InvokeModel.
      class StabilityImages < InvokeModel
        GENERATION_MODELS = %w[
          stability.sd3-5-large-v1:0 stability.stable-image-core-v1:1 stability.stable-image-ultra-v1:1
        ].freeze
        INPAINT_MODEL = 'stability.stable-image-inpaint-v1:0'
        MODELS = (GENERATION_MODELS + [INPAINT_MODEL]).freeze
        ASPECT_RATIOS = %w[16:9 1:1 21:9 2:3 3:2 4:5 5:4 9:16 9:21].freeze
        IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze

        def paint(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {})
          track_usage(:image) do
            payload = render_image_payload(prompt, model:, size:, count:, with:, mask:, provider_options:)
            response = signed_post("/model/#{model}/invoke", payload)
            images = parse_image_responses(response, model:)
            images.each { |image| image.config = @config }
            images.one? ? images.first : images
          end
        end

        def render_image_payload(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {})
          RubyLLM.logger.debug { 'Stability image models return one image per request' } if count && count > 1
          attachments = Attachment.wrap(with, config: @config)
          payload = { prompt: }.merge(render_image_inputs(attachments, model:, mask:, size:))
          payload.merge(provider_options.transform_keys(&:to_sym))
        end

        def parse_image_responses(response, model:)
          images = Array(response.body['images']).compact.reject(&:empty?)
          if images.empty?
            reasons = Array(response.body['finish_reasons']).compact.join(', ')
            message = reasons.empty? ? 'Bedrock returned no images' : "Bedrock image generation failed: #{reasons}"
            raise Error.new(message, response:)
          end

          images.map do |data|
            mime_type = RubyLLM::Files::MimeType.for(StringIO.new(Base64.decode64(data)))
            raise Error.new('Bedrock returned invalid image data', response:) unless IMAGE_TYPES.include?(mime_type)

            Image.new(data:, model:, mime_type:)
          end
        end

        private

        def render_image_inputs(attachments, model:, mask:, size:)
          return render_inpaint_inputs(attachments, mask:, size:) if model.end_with?(INPAINT_MODEL)
          raise UnsupportedAttachmentError, 'image mask' if mask
          return { aspect_ratio: image_aspect_ratio(size) }.compact if attachments.empty?
          raise UnsupportedAttachmentError, 'image reference' unless model.end_with?('stability.sd3-5-large-v1:0')

          { image: single_image(attachments, size:), mode: 'image-to-image', strength: 0.5 }
        end

        def render_inpaint_inputs(attachments, mask:, size:)
          payload = { image: single_image(attachments, size:) }
          payload[:mask] = single_image(Attachment.wrap(mask, config: @config), size: nil) if mask
          payload
        end

        def single_image(attachments, size:)
          raise ArgumentError, 'with: must contain exactly one image' unless attachments.one?
          raise ArgumentError, 'size: cannot change dimensions when editing a Stability image' if size

          encoded_image(attachments.first)
        end

        def encoded_image(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type unless IMAGE_TYPES.include?(attachment.mime_type)

          attachment.encoded
        end

        def image_aspect_ratio(size)
          return unless size

          match = size.to_s.match(/\A(\d+)\s*[x×:]\s*(\d+)\z/i)
          raise ArgumentError, "Invalid image size: #{size.inspect}" unless match

          width, height = match.captures.map(&:to_i)
          raise ArgumentError, "Invalid image size: #{size.inspect}" unless width.positive? && height.positive?

          ratio = matching_aspect_ratio(width, height)
          raise ArgumentError, "Unsupported Stability image aspect ratio: #{size}" unless ratio

          ratio
        end

        def matching_aspect_ratio(width, height)
          ASPECT_RATIOS.find do |candidate|
            ratio_width, ratio_height = candidate.split(':').map(&:to_i)
            width * ratio_height == height * ratio_width
          end
        end
      end
    end
  end
end
