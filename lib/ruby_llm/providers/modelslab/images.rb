# frozen_string_literal: true

module RubyLLM
  module Providers
    class ModelsLab
      # Image generation methods for the ModelsLab API integration
      module Images
        module_function

        def images_url
          'images/text2img'
        end

        def render_image_payload(prompt, model:, size:)
          width, height = size.split('x').map(&:to_i)

          {
            key: @config.modelslab_api_key,
            prompt: prompt,
            model_id: model || 'flux',
            width: width,
            height: height,
            samples: 1,
            num_inference_steps: 30,
            guidance_scale: 7.5,
            safety_checker: 'no'
          }
        end

        def parse_image_response(response, model:)
          body = response.body

          case body['status']
          when 'success'
            image_data = body['output']&.first
            return Image.new if image_data.nil?

            Image.new(
              url: image_data,
              mime_type: 'image/png',
              model_id: model,
              data: body['base64']
            )
          when 'processing'
            # For async requests, raise an error with the request ID
            raise RubyLLM::Error, "Image generation is processing. Request ID: #{body['id']}. Use the fetch endpoint to retrieve the result."
          else
            raise RubyLLM::Error, body['message'] || 'Unknown error from ModelsLab API'
          end
        end
      end
    end
  end
end
