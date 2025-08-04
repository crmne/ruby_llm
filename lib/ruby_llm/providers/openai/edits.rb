# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Image generation methods for the OpenAI API integration
      module Edits
        module_function

        def edits_url
          'images/edits'
        end

        # Options:
        # - size: '1024x1024'
        # - quality: 'low'
        # - user: 'user_123'
        # See https://platform.openai.com/docs/api-reference/images/createEdit
        def render_edit_payload(prompt, model:, with:, options:)
          options.merge({
                          model:,
                          prompt:,
                          image: ImageAttachments.new(with[:image]).format,
                          n: 1
                        })
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
