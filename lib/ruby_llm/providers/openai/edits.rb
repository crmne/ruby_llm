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

        def render_edit_payload(prompt, model:, size:, with:)
          payload = {
            model: model,
            prompt: prompt,
            image: ImageAttachments.new(with[:image]).format,
            size: size,
            n: 1
          }
        end

        def parse_edit_response(response)
          data = response.body
          image_data = data['data'].first

          Image.new(
            data: image_data['b64_json'], # Edits API returns base64 when requested
            mime_type: 'image/png',
            revised_prompt: image_data['revised_prompt'], # May or may not be present
            # Attempt to get model from headers, fallback needed? API might not return it consistently here.
            model_id: response.headers['openai-model'] || response.headers['x-request-id'] # Placeholder if model isn't in header
          )
        end
      end
    end
  end
end
