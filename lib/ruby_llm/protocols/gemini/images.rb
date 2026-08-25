# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Image generation methods for the Gemini API implementation
      module Images
        IMAGE_SIZES = %w[512 512P 512PX 1K 2K 4K].freeze
        ASPECT_RATIO = /\A\d+:\d+\z/
        PIXEL_DIMENSIONS = /\A(\d+)\s*[x×]\s*(\d+)\z/i

        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          id = model_id(@model)

          "models/#{id}:#{image_endpoint_action(id)}"
        end

        def render_image_payload(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          @model = model
          payload = if gemini_image_model?(model)
                      render_gemini_image_payload(prompt, with:, count:, size:)
                    else
                      render_imagen_payload(prompt, count:, size:)
                    end

          Utils.deep_merge(payload, provider_options)
        end

        def parse_image_response(response, model:)
          parse_image_responses(response, model:).first
        end

        def parse_image_responses(response, model:)
          data = response.body
          return parse_gemini_image_responses(data, model:) if gemini_image_model?(model)

          parse_imagen_responses(data, model:)
        end

        private

        def validate_paint_inputs!(with:, mask:)
          if gemini_image_model?(@model)
            raise UnsupportedAttachmentError, 'image mask' if mask

            return
          end

          return if with.nil? && mask.nil?

          raise UnsupportedAttachmentError, 'image reference'
        end

        def render_imagen_payload(prompt, count: nil, size: nil)
          RubyLLM.logger.debug { "Ignoring size #{size}. Imagen sizing is not supported." } if size

          {
            instances: [
              {
                prompt: prompt
              }
            ],
            parameters: {
              sampleCount: count || 1
            }
          }
        end

        def render_gemini_image_payload(prompt, with:, count: nil, size: nil)
          generation_config = { responseModalities: %w[TEXT IMAGE] }
          generation_config[:candidateCount] = count if count && count > 1
          image_config = build_image_config(size)
          generation_config[:imageConfig] = image_config if image_config

          {
            contents: [
              {
                role: 'user',
                parts: Media.format_content(prompt, image_attachments(with))
              }
            ],
            generationConfig: generation_config
          }
        end

        # Gemini sizes an image by aspect ratio and resolution tier rather
        # than by pixel dimensions, so WxH becomes the ratio it reduces to.
        def build_image_config(size)
          value = size.to_s.strip
          return nil if value.empty?
          return { imageSize: value.upcase } if IMAGE_SIZES.include?(value.upcase)
          return { aspectRatio: value } if value.match?(ASPECT_RATIO)

          match = value.match(PIXEL_DIMENSIONS)
          raise ArgumentError, unsupported_size_message(size) unless match

          { aspectRatio: aspect_ratio(match[1].to_i, match[2].to_i) }
        end

        def aspect_ratio(width, height)
          raise ArgumentError, unsupported_size_message("#{width}x#{height}") unless width.positive? && height.positive?

          divisor = width.gcd(height)
          "#{width / divisor}:#{height / divisor}"
        end

        def unsupported_size_message(size)
          "Gemini cannot generate an image of size #{size.inspect}. Give pixel dimensions such as " \
            '"1024x1024", an aspect ratio such as "16:9", or a resolution ' \
            "such as #{IMAGE_SIZES.join(', ')}."
        end

        def parse_imagen_responses(data, model:)
          predictions = Array(data['predictions']).select { |prediction| prediction['bytesBase64Encoded'] }
          raise Error, 'Unexpected response format from Gemini image generation API' if predictions.empty?

          predictions.map do |image_data|
            Image.new(
              data: image_data['bytesBase64Encoded'],
              mime_type: image_data['mimeType'] || 'image/png',
              model: model
            )
          end
        end

        def parse_gemini_image_responses(data, model:)
          parts = gemini_image_parts(data)
          raise Error, 'Unexpected response format from Gemini image generation API' if parts.empty?

          parts.map.with_index do |image_data, index|
            Image.new(
              data: image_data['data'],
              mime_type: image_data['mimeType'] || 'image/png',
              model: data['modelVersion'] || model,
              usage: index.zero? ? gemini_image_usage(data) : {}
            )
          end
        end

        def gemini_image_parts(data)
          Array(data['candidates']).filter_map do |candidate|
            parts = candidate.dig('content', 'parts') || []
            parts.filter_map { |part| part['inlineData'] }.find do |inline_data|
              image_mime_type?(inline_data['mimeType']) && inline_data['data']
            end
          end
        end

        def image_mime_type?(mime_type)
          mime_type.nil? || mime_type.start_with?('image/')
        end

        def gemini_image_usage(data)
          {
            'input_tokens' => input_tokens(data),
            'output_tokens' => calculate_output_tokens(data)
          }.compact
        end

        def image_attachments(sources)
          Attachment.wrap(sources, config: @config).each do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          end
        end

        def gemini_image_model?(model)
          id = model_id(model).downcase
          return true if id.start_with?('nano-banana', 'nanobanana')

          id.start_with?('gemini-') && id.include?('-image')
        end

        def image_endpoint_action(model)
          gemini_image_model?(model) ? 'generateContent' : 'predict'
        end

        def model_id(model)
          model.respond_to?(:id) ? model.id : model.to_s
        end
      end
    end
  end
end
