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

        def render_image_payload(prompt, model:, size:)
          @model = model
          if uses_generate_content?(model)
            aspect_ratio = calculate_aspect_ratio(size)
            RubyLLM.logger.debug "Using aspect ratio #{aspect_ratio} for size #{size}"
            {
              contents: [
                {
                  role: 'user',
                  parts: [
                    {
                      text: prompt
                    }
                  ]
                }
              ],
              generationConfig: {
                responseModalities: [
                  'IMAGE'
                ],
                imageConfig: {
                  aspectRatio: aspect_ratio
                }
              }
            }
          else
            RubyLLM.logger.debug "Ignoring size #{size}. Gemini does not support image size customization."
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

        SUPPORTED_ASPECT_RATIOS = {
          # Landscape
          '21:9' => 21.0 / 9.0,
          '16:9' => 16.0 / 9.0,
          '4:3' => 4.0 / 3.0,
          '3:2' => 3.0 / 2.0,
          # Square
          '1:1' => 1.0,
          # Portrait
          '9:16' => 9.0 / 16.0,
          '3:4' => 3.0 / 4.0,
          '2:3' => 2.0 / 3.0,
          # Flexible
          '5:4' => 5.0 / 4.0,
          '4:5' => 4.0 / 5.0
        }.freeze

        private

        def calculate_aspect_ratio(size)
          # Default to square if no size specified or invalid format
          return '1:1' if size.nil? || size.empty?

          # Extract width and height from size string (e.g., "124x421", "1024x768")
          match = size.match(/(\d+)[x×](\d+)/i)
          return '1:1' unless match

          width = match[1].to_f
          height = match[2].to_f
          return '1:1' if width <= 0 || height <= 0

          target_ratio = width / height

          # Find the closest supported aspect ratio
          closest_ratio = SUPPORTED_ASPECT_RATIOS.min_by do |_ratio_name, ratio_value|
            (ratio_value - target_ratio).abs
          end

          closest_ratio[0]
        end

        def uses_generate_content?(model)
          model = RubyLLM::Models.find(model, :vertexai)
          supported_methods = model.metadata[:supported_generation_methods]
          supported_methods.include?('generateContent')
        rescue ModelNotFoundError
          false
        end

        def parse_image_response(response, model:)
          data = response.body

          image_data = if uses_generate_content?(model)
                         raw_data = data.dig('candidates', 0, 'content', 'parts', 0, 'inlineData')
                         { 'bytesBase64Encoded' => raw_data['data'], 'mimeType' => raw_data['mimeType'] }
                       else
                         data['predictions']&.first
                       end

          mime_type = image_data['mimeType'] || 'image/png'
          base64_data = image_data['bytesBase64Encoded']

          Image.new(
            data: base64_data,
            mime_type: mime_type,
            model_id: model
          )
        end
      end
    end
  end
end
