# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Image generation methods for the Gemini API implementation
      module Images
        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          id = model_id(@model)

          "models/#{id}:#{image_endpoint_action(id)}"
        end

        def render_image_payload(prompt, model:, size:, with: nil, mask: nil, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          RubyLLM.logger.debug { "Ignoring size #{size}. Gemini does not support image size customization." }
          @model = model
          payload = if gemini_image_model?(model)
                      render_gemini_image_payload(prompt, with:)
                    else
                      render_imagen_payload(prompt)
                    end

          Utils.deep_merge(payload, provider_options)
        end

        def parse_image_response(response, model:)
          data = response.body
          return parse_gemini_image_response(data, model:) if gemini_image_model?(model)

          parse_imagen_response(data, model:)
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

        def render_imagen_payload(prompt)
          {
            instances: [
              {
                prompt: prompt
              }
            ],
            parameters: {
              sampleCount: 1
            }
          }
        end

        def render_gemini_image_payload(prompt, with:)
          {
            contents: [
              {
                role: 'user',
                parts: Media.format_content(prompt, image_attachments(with))
              }
            ],
            generationConfig: {
              responseModalities: %w[TEXT IMAGE]
            }
          }
        end

        def parse_imagen_response(data, model:)
          image_data = data['predictions']&.first
          unless image_data&.key?('bytesBase64Encoded')
            raise Error, 'Unexpected response format from Gemini image generation API'
          end

          Image.new(
            data: image_data['bytesBase64Encoded'],
            mime_type: image_data['mimeType'] || 'image/png',
            model: model
          )
        end

        def parse_gemini_image_response(data, model:)
          image_data = gemini_image_part(data)
          raise Error, 'Unexpected response format from Gemini image generation API' unless image_data

          Image.new(
            data: image_data['data'],
            mime_type: image_data['mimeType'] || 'image/png',
            model: data['modelVersion'] || model,
            usage: gemini_image_usage(data)
          )
        end

        def gemini_image_part(data)
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          parts.filter_map { |part| part['inlineData'] }.find do |inline_data|
            image_mime_type?(inline_data['mimeType']) && inline_data['data']
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
          Attachment.wrap(sources).each do |attachment|
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
