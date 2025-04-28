# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Image generation methods for the OpenAI API integration
      module Edits
        module_function

        def edits_url
          'v1/images/edits' # Added v1 prefix, common practice
        end

        def render_edit_payload(prompt, model:, size:, with:)
          images = Array(with[:image])
          mask_source = with[:mask] # Renamed from mask_path

          raise ArgumentError, 'Missing required :image in `with` argument' if images.empty?
          # OpenAI edits API only supports ONE image
          raise ArgumentError, 'OpenAI image edits currently support only one input image.' if images.length > 1

          image_source = images.first

          # Use ImageAttachment to prepare the image part
          image_part = ImageAttachment.new(image_source, :image).prepare

          payload = {
            model: model,
            prompt: prompt,
            image: image_part,
            size: size,
            n: 1, # OpenAI Edits API always returns 1 image
            response_format: 'b64_json' # Match parser expectation
          }
          # Handle mask: must be PNG < 4MB, can be URL or path
          if mask_source
            # Use ImageAttachment to prepare the mask part
            mask_part = ImageAttachment.new(mask_source, :mask).prepare
            payload[:mask] = mask_part
          end

          payload
        end

        def parse_edit_response(response)
          data = response.body
          # Improved error checking based on response status and body structure
          unless response.success? && data.is_a?(Hash) && data['data']&.first
            api_error_message = data.is_a?(Hash) && data['error'] ? data['error']['message'] : response.body.to_s
            raise RubyLLM::ApiError, "OpenAI image edit failed: #{response.status} - #{api_error_message}"
          end

          image_data = data['data'].first

          # Expecting PNG from the edits endpoint
          mime_type = ImageAttachment::REQUIRED_MIME_TYPE

          Image.new(
            data: image_data['b64_json'], # Edits API returns base64 when requested
            mime_type: mime_type,
            revised_prompt: image_data['revised_prompt'], # May or may not be present
            # Attempt to get model from headers, fallback needed? API might not return it consistently here.
            model_id: response.headers['openai-model'] || response.headers['x-request-id'] # Placeholder if model isn't in header
          )
        end
      end
    end
  end
end
