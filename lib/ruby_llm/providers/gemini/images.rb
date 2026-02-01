# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Image generation methods for the Gemini API implementation
      module Images
        def images_url
          if uses_generate_content?(@model)
            "models/#{@model}:generateContent"
          else
            "models/#{@model}:predict"
          end
        end

        def render_image_payload(prompt, model:, size:, with: [])
          RubyLLM.logger.debug "Ignoring size #{size}. Gemini does not support image size customization."
          @model = model

          if uses_generate_content?(model)
            # Use generateContent format for gemini-flash-image models
            parts = [{ text: prompt }]

            with.each do |attachment|
              parts << {
                inline_data: {
                  mime_type: detect_mime_type(attachment),
                  data: encode_image_to_base64(attachment)
                }
              }
            end

            {
              contents: [
                {
                  parts: parts
                }
              ]
            }
          else
            # Use predict format for imagen models (Vertex AI)
            RubyLLM.logger.debug 'Ignoring attachments. Imagen models do not support image editing.' if with.any?

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
        end

        def uses_generate_content?(model)
          # gemini-flash-image models use generateContent, imagen models use predict
          model.match?(/gemini.*flash.*image/)
        end

        def detect_mime_type(file_path)
          expanded_path = File.expand_path(file_path)
          Marcel::MimeType.for(Pathname.new(expanded_path))
        end

        def encode_image_to_base64(file_path)
          expanded_path = File.expand_path(file_path)
          Base64.strict_encode64(File.binread(expanded_path))
        end

        def parse_image_response(response, model:)
          # Parse JSON if it's still a string (happens with some responses)
          data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body

          if uses_generate_content?(model)
            mime_type, base64_data = parse_generate_content_data(data, response)
          else
            mime_type, base64_data = parse_predict_data(data, response)
          end

          Image.new(
            data: base64_data,
            mime_type: mime_type,
            model_id: model
          )
        end

        def parse_generate_content_data(data, response)
          candidate = data['candidates']&.first
          parts = candidate&.dig('content', 'parts')

          # Find the part with image data (inlineData, not inline_data - Gemini uses camelCase)
          image_part = parts&.find { |p| p.key?('inlineData') }

          raise Error.new(response, 'Unexpected response format from Gemini generateContent API') unless image_part

          inline_data = image_part['inlineData']
          mime_type = inline_data['mimeType'] || 'image/png'
          base64_data = inline_data['data']

          [mime_type, base64_data]
        end

        def parse_predict_data(data, response)
          image_data = data['predictions']&.first

          unless image_data&.key?('bytesBase64Encoded')
            raise Error.new(response, 'Unexpected response format from Gemini predict API')
          end

          mime_type = image_data['mimeType'] || 'image/png'
          base64_data = image_data['bytesBase64Encoded']

          [mime_type, base64_data]
        end
      end
    end
  end
end
