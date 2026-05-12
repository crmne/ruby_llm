# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Image generation methods for the Gemini API implementation.
      #
      # Routes to one of two protocols depending on the model:
      # - Imagen models (imagen-*): :predict endpoint with instances/parameters payload.
      # - Gemini Image models (everything else, e.g. gemini-2.5-flash-image, nano-banana-*):
      #   :generateContent endpoint with contents/parts payload, same protocol as chat.
      module Images
        SIZE_TO_ASPECT_RATIO = {
          '1024x1024' => '1:1',
          '1792x1024' => '16:9',
          '1024x1792' => '9:16',
          '1408x1024' => '4:3',
          '1024x1408' => '3:4'
        }.freeze

        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          imagen?(@model) ? "models/#{@model}:predict" : "models/#{@model}:generateContent"
        end

        def render_image_payload(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Metrics/ParameterLists
          @model = model
          reject_unsupported_inputs!(model, with: with, mask: mask)

          payload = if imagen?(model)
                      imagen_payload(prompt, size: size)
                    else
                      gemini_image_payload(prompt, size: size, with: with)
                    end
          Utils.deep_merge(payload, params)
        end

        def parse_image_response(response, model:)
          if imagen?(model)
            parse_imagen_response(response, model: model)
          else
            parse_gemini_image_response(response, model: model)
          end
        end

        # Override the base provider's blanket rejection of `with:`/`mask:`. The model-aware
        # checks live in render_image_payload because the base flow calls validate first,
        # before render — at that point the model id is not yet on @model.
        def validate_paint_inputs!(with:, mask:); end

        private

        def imagen?(model)
          model.to_s.start_with?('imagen')
        end

        def reject_unsupported_inputs!(model, with:, mask:)
          raise UnsupportedAttachmentError, 'Gemini image generation does not support masks' unless mask.nil?
          return if with.nil?
          return unless imagen?(model)

          raise UnsupportedAttachmentError, 'Imagen does not support image references in paint'
        end

        # --- Imagen path (unchanged behavior) ---

        def imagen_payload(prompt, size:)
          RubyLLM.logger.debug { "Ignoring size #{size}. Imagen does not support image size customization." }
          {
            instances: [{ prompt: prompt }],
            parameters: { sampleCount: 1 }
          }
        end

        def parse_imagen_response(response, model:)
          image_data = response.body['predictions']&.first

          unless image_data&.key?('bytesBase64Encoded')
            raise Error, 'Unexpected response format from Gemini image generation API'
          end

          Image.new(
            data: image_data['bytesBase64Encoded'],
            mime_type: image_data['mimeType'] || 'image/png',
            model_id: model
          )
        end

        # --- Gemini Image path ---

        def gemini_image_payload(prompt, size:, with:)
          parts = build_image_parts(with) + [{ text: prompt }]
          {
            contents: [{ role: 'user', parts: parts }],
            generationConfig: {
              # Gemini Image models require both modalities in the response config
              # even when only the IMAGE part is consumed.
              responseModalities: %w[IMAGE TEXT],
              imageConfig: {
                aspectRatio: aspect_ratio_for(size),
                imageSize: '1K'
              }
            }
          }
        end

        def build_image_parts(with)
          Array(with).filter_map do |source|
            next if source.nil? || (source.is_a?(String) && source.strip.empty?)

            attachment = RubyLLM::Attachment.new(source)
            if attachment.type == :unknown
              raise UnsupportedAttachmentError,
                    "Gemini image generation does not support attachment type: #{attachment.mime_type}"
            end

            format_attachment(attachment)
          end
        end

        def aspect_ratio_for(size)
          SIZE_TO_ASPECT_RATIO[size] || begin
            RubyLLM.logger.debug { "Unmapped size #{size}; defaulting Gemini aspectRatio to 1:1" }
            '1:1'
          end
        end

        def parse_gemini_image_response(response, model:)
          parts = response.body.dig('candidates', 0, 'content', 'parts') || []
          inline = parts.filter_map { |p| p['inlineData'] || p['inline_data'] }.first

          raise Error, 'No inlineData image part in Gemini image generation response' unless inline

          Image.new(
            data: inline['data'],
            mime_type: inline['mimeType'] || inline['mime_type'] || 'image/png',
            model_id: model,
            usage: response.body['usageMetadata'] || {}
          )
        end
      end
    end
  end
end
