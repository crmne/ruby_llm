# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Image generation methods for the OpenRouter API integration.
      # OpenRouter has a unified images endpoint that generates and edits
      # images across providers and reports the exact cost of each call.
      module Images
        module_function

        def images_url(with: nil, mask: nil) # rubocop:disable Lint/UnusedMethodArgument
          'images'
        end

        def render_image_payload(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          RubyLLM.logger.debug { "Ignoring size #{size}. Use aspect_ratio/resolution provider options instead." }
          if count && count > 1
            RubyLLM.logger.debug do
              "Ignoring count #{count}. OpenRouter generates one image per request."
            end
          end
          payload = { model: model, prompt: prompt }
          references = build_input_references(with)
          payload[:input_references] = references if references.any?
          payload.merge(provider_options)
        end

        def build_input_references(with)
          Attachment.wrap(with, config: @config).map do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

            Protocols::ChatCompletions::Media.format_image(attachment)
          end
        end

        def validate_paint_inputs!(with:, mask:) # rubocop:disable Lint/UnusedMethodArgument
          raise UnsupportedAttachmentError, 'image mask' unless mask.nil?
        end

        # OpenRouter's images endpoint returns one image per request.
        def parse_image_responses(response, model:)
          [parse_image_response(response, model:)]
        end

        def parse_image_response(response, model:)
          data = response.body
          image_data = Array(data['data']).first

          raise Error, 'Unexpected response format from OpenRouter image API' unless image_data

          Image.new(
            data: image_data['b64_json'],
            mime_type: image_data['media_type'] || 'image/png',
            model: model,
            usage: image_usage(data['usage'] || {})
          )
        end

        def image_usage(usage)
          {
            'input_tokens' => usage['prompt_tokens'],
            'output_tokens' => usage['completion_tokens'],
            'cost' => reported_cost(usage)
          }.compact
        end
      end
    end
  end
end
