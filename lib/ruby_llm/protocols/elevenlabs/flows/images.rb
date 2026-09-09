# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      class Flows
        module Images # :nodoc: all
          MASK_MODELS = %w[gpt-image-1 gpt-image-1.5 gpt-image-2].freeze

          def images_url(**)
            'v1/flows/image'
          end

          def post_image(payload, **)
            @connection.post images_url, payload, usage: @usage_tracker, idempotent: false
          end

          def render_image_payload(prompt, model:, size:, with: nil, mask: nil, provider_options: {}, **)
            images = Attachment.wrap(with, config: @config)
            payload = { model_id: model, prompt: }
            payload[:images] = images.map { |image| render_media_reference(image) } if images.any?
            payload[:aspect_ratio] = image_aspect_ratio(size) if size && size != 'auto'
            if mask
              raise ArgumentError, 'ElevenLabs image masks require a GPT Image model' unless MASK_MODELS.include?(model)

              payload[:mask] = render_media_reference(Attachment.wrap(mask, config: @config).first)
            end
            Support::Utils.deep_merge(payload, provider_options)
          end

          def parse_image_response(response, model:)
            id = response.body.fetch('id')
            body = wait_for_image(id)
            Image.new(url: body.fetch('content_url'), mime_type: body.fetch('content_mime_type'), model:)
          end

          def wait_for_image(id)
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @config.request_timeout
            loop do
              body = @connection.get("#{images_url}/#{id}").body
              state = parse_generation_status(body)
              return body if state[:status] == :completed
              raise Error, "ElevenLabs image generation failed: #{state[:error]}" if state[:status] == :failed
              if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
                raise Error, "ElevenLabs image generation timed out: #{id}"
              end

              sleep 1
            end
          end

          def validate_paint_inputs!(with:, mask:)
            images = Attachment.wrap(with, config: @config)
            raise ArgumentError, 'An image mask requires a source image' if mask && images.empty?

            images += Attachment.wrap(mask, config: @config) if mask
            images.each do |image|
              raise UnsupportedAttachmentError, image.mime_type unless image.image?
            end
          end

          def image_aspect_ratio(size)
            match = size.to_s.match(/\A([1-9]\d*)x([1-9]\d*)\z/)
            raise ArgumentError, 'size must be widthxheight or auto' unless match

            width, height = match.captures.map(&:to_i)
            divisor = width.gcd(height)
            "#{width / divisor}:#{height / divisor}"
          end
        end
      end
    end
  end
end
