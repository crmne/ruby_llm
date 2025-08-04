# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Image generation methods for the OpenAI API integration
      module Images
        def paint(prompt, model:, size:, connection:, with:, params:)
          @with = with
          connection = connection_multipart(connection.config) if needs_multipart_connection?(connection)
          super(prompt, model:, size:, connection:, with:, params:)
        end

        private

        def needs_multipart_connection?(connection)
          @with && !has_multipart_middleware?(connection)
        end

        def has_multipart_middleware?(connection)
          connection.connection.builder.handlers.include?(Faraday::Multipart::Middleware)
        end

        module_function

        def images_url
          @with.nil? ? generation_url : edits_url
        end

        def generation_url
          'images/generations'
        end

        def edits_url
          'images/edits'
        end

        def render_image_payload(prompt, model:, size:, with:, params:)
          return render_edit_payload(prompt, model:, with:, params:) unless with.nil?

          {
            model: model,
            prompt: prompt,
            n: 1,
            size: size
          }
        end

        def render_edit_payload(prompt, model:, with:, params:)
          params.merge({
                          model:,
                          prompt:,
                          image: ImageAttachments.new(with).format,
                          n: 1
                        })
        end

        def parse_image_response(response, model:)
          return parse_edit_response(response, model:) if @with

          data = response.body
          image_data = data['data'].first

          Image.new(
            url: image_data['url'],
            mime_type: 'image/png', # DALL-E typically returns PNGs
            revised_prompt: image_data['revised_prompt'],
            model_id: model,
            data: image_data['b64_json']
          )
        end


        def parse_edit_response(response, model:)
          data = response.body
          image_data = data['data'].first
          Image.new(
            data: image_data['b64_json'], # Edits API returns base64 when requested
            mime_type: 'image/png',
            usage: data['usage'],
            model_id: model
          )
        end
      end
    end
  end
end
