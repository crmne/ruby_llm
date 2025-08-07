# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Image generation methods for the OpenAI API integration
      module Images
        def paint(prompt, model:, size:, with:, params:)
          @operation = with.nil? ? :generation : :editing
          @connection = connection_multipart(@connection.config) if editing? && !multipart_middleware?(@connection)
          super
        end

        private

        def editing?
          @operation == :editing
        end

        def generating?
          @operation == :generation
        end

        def multipart_middleware?(connection)
          connection.connection.builder.handlers.include?(Faraday::Multipart::Middleware)
        end

        module_function

        def images_url
          generating? ? generation_url : edits_url
        end

        def generation_url
          'images/generations'
        end

        def edits_url
          'images/edits'
        end

        def render_image_payload(prompt, model:, size:, with:, params:)
          if generating?
            render_generation_payload(prompt, model:, size:)
          else
            render_edit_payload(prompt, model:, with:, params:)
          end
        end

        def render_generation_payload(prompt, model:, size:)
          {
            model: model,
            prompt: prompt,
            n: 1,
            size: size
          }
        end

        def render_edit_payload(prompt, model:, with:, params:)
          content = Content.new(prompt, with)
          params[:image] = []
          content.attachments.each do |attachment|
            params[:image] << Faraday::UploadIO.new(StringIO.new(attachment.content), attachment.mime_type,
                                                    attachment.filename)
          end
          params.merge({
                         model:,
                         prompt: content.text,
                         n: 1
                       })
        end

        def parse_image_response(response, model:)
          if generating?
            parse_generation_response(response, model:)
          else
            parse_edit_response(response, model:)
          end
        end

        def parse_generation_response(response, model:)
          data = response.body
          image_data = data['data'].first

          Image.new(
            url: image_data['url'],
            mime_type: 'image/png',
            revised_prompt: image_data['revised_prompt'],
            model_id: model,
            data: image_data['b64_json'],
            usage: data['usage']
          )
        end

        def parse_edit_response(response, model:)
          data = response.body
          image_data = data['data'].first
          Image.new(
            mime_type: 'image/png',
            model_id: model,
            data: image_data['b64_json'],
            usage: data['usage']
          )
        end
      end
    end
  end
end
