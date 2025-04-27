# frozen_string_literal: true

require 'faraday/multipart'

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
          image_path = Array(with[:image])
          mask_path = with[:mask]

          raise ArgumentError, 'Missing required :image path in `with` argument' if image_path.empty?

          payload = {
            model:,
            prompt:,
            image: image_path.map { |path| attach_image(path) },
            size: size,
            n: 1
          }
          payload[:mask] = attach_image(mask_path) if mask_path.is_a?(String)

          payload # Return the hash directly
        end

        def attach_image(source)
          # Disallow remote URLs for now, as FilePart expects a local path
          if source.start_with?('http://') || source.start_with?('https://')
            raise ArgumentError, "Remote URLs are not supported for image edits: #{source}"
          end

          expanded_path = File.expand_path(source)
          raise ArgumentError, "Image file not found: #{expanded_path}" unless File.exist?(expanded_path)

          # Use Faraday::Multipart::FilePart for compatibility with newer Faraday versions
          Faraday::Multipart::FilePart.new(
            expanded_path,
            mime_type_for_image(expanded_path),
            File.basename(expanded_path)
          )
        end

        def mime_type_for_image(path)
          ext = File.extname(path).downcase.delete('.')
          case ext
          when 'png' then 'image/png' # OpenAI requires PNG for edits
          when 'webp' then 'image/webp'
          when 'jpeg' then 'image/jpeg'
          else
            raise ArgumentError, "Invalid image format for edits: '#{ext}'. Only PNG, WebP, and JPEG are supported."
          end
        end

        # Assuming parse_image_response exists elsewhere or is handled by the generic provider
        def parse_edit_response(response)
          data = response.body
          image_data = data['data'].first

          Image.new(
            data: image_data['b64_json'],
            mime_type: 'image/png', # DALL-E typically returns PNGs
            revised_prompt: image_data['revised_prompt'],
            model_id: data['model']
          )
        end
      end
    end
  end
end
