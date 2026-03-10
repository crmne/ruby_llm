# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Image generation methods for the OpenAI API integration
      module Images
        module_function

        def images_url(model: nil, with: [])
          _model = model

          with.any? ? 'images/edits' : 'images/generations'
        end

        def render_image_payload(prompt, model:, size:, with: [])
          if with.any?
            validate_edit_support!(model)
            default_generation_payload(prompt, model:, size:)
              .merge(image_attachments_payload(with))
              .compact
          else
            default_generation_payload(prompt, model:, size:)
          end
        end

        def image_attachments_payload(attachments)
          return {} unless attachments.any?

          if attachments.one?
            { image: build_image_file_part(attachments.first) }
          else
            { image: attachments.map { |attachment| build_image_file_part(attachment) } }
          end
        end

        def default_generation_payload(prompt, model:, size:)
          {
            model: model,
            prompt: prompt,
            n: 1,
            size: size
          }
        end

        def validate_edit_support!(model)
          return if model.match?(/^gpt-image-/) || model == 'dall-e-2'

          raise Error, "Image editing is only supported for gpt-image-* and dall-e-2 models. Got: #{model}"
        end

        def build_image_file_part(file_path)
          expanded_path = File.expand_path(file_path)
          raise ArgumentError, "File not found: #{file_path}" unless File.exist?(expanded_path)

          mime_type = Marcel::MimeType.for(Pathname.new(expanded_path))

          Faraday::Multipart::FilePart.new(
            expanded_path,
            mime_type,
            File.basename(expanded_path)
          )
        end

        def parse_image_response(response, model:)
          # Parse JSON if it's still a string (happens with multipart responses)
          data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
          image_data = data['data'].first

          Image.new(
            url: image_data['url'],
            mime_type: 'image/png', # DALL-E typically returns PNGs
            revised_prompt: image_data['revised_prompt'],
            model_id: model,
            data: image_data['b64_json']
          )
        end
      end
    end
  end
end
