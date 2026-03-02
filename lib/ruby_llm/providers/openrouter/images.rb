# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Image generation methods for the OpenRouter API integration.
      # OpenRouter uses the chat completions endpoint for image generation
      # instead of a dedicated images endpoint.
      module Images
        module_function

        def images_url
          'chat/completions'
        end

        def render_image_payload(prompt, model:, size:)
          RubyLLM.logger.debug "Ignoring size #{size}. OpenRouter image generation does not support size parameter."
          {
            model: model,
            messages: [
              {
                role: 'user',
                content: prompt
              }
            ],
            modalities: %w[image text]
          }
        end

        def parse_image_response(response, model:)
          data = response.body
          message = data.dig('choices', 0, 'message')

          unless message&.key?('images') && message['images']&.any?
            raise Error.new(nil, 'Unexpected response format from OpenRouter image generation API')
          end

          image_data = message['images'].first
          image_url = image_data.dig('image_url', 'url') || image_data['url']

          raise Error.new(nil, 'No image URL found in OpenRouter response') unless image_url

          build_image_from_url(image_url, model)
        end

        def build_image_from_url(image_url, model)
          if image_url.start_with?('data:')
            # Parse data URL format: data:image/png;base64,<data>
            match = image_url.match(/^data:([^;]+);base64,(.+)$/)
            raise Error.new(nil, 'Invalid data URL format from OpenRouter') unless match

            Image.new(
              data: match[2],
              mime_type: match[1],
              model_id: model
            )
          else
            # Regular URL
            Image.new(
              url: image_url,
              mime_type: 'image/png',
              model_id: model
            )
          end
        end
      end
    end
  end
end
