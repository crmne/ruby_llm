# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Grok Imagine video generation. Jobs take a single reference image
      # as a URL, file id, or data URI, and finished videos are public
      # hosted URLs.
      module Videos
        def video_url
          'videos/generations'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          payload = { model: model, prompt: prompt }
          if (image = with.first)
            payload[:image] = { url: video_image_reference(image) }
          end

          payload.merge(provider_options)
        end

        def parse_video_job(response, model:)
          id = response.body['request_id']
          raise Error.new('xAI did not return a video request id', response:) unless id

          VideoJob.new(id: id, protocol: self, model: model, raw: response.body)
        end

        def video_job_url(job)
          "videos/#{job.id}"
        end

        def parse_video_job_status(response, job:) # rubocop:disable Lint/UnusedMethodArgument
          body = response.body
          case body['status']
          when 'done' then { status: :completed, raw: body }
          when 'failed', 'expired' then { status: :failed, raw: body, error: body['error'] || body['status'] }
          else { status: :pending, raw: body }
          end
        end

        def download_video(job)
          video = job.raw['video'] || {}

          Video.new(
            url: video['url'],
            mime_type: 'video/mp4',
            duration: video['duration'],
            model: job.raw['model'] || job.model,
            raw: job.raw
          )
        end

        private

        def validate_animate_inputs!(with:)
          raise Error, 'xAI video generation takes a single reference image' if with.size > 1

          with.each do |attachment|
            next if attachment.provider_file? || attachment.url?
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          end
        end

        def video_image_reference(attachment)
          return attachment.provider_file_id if attachment.provider_file?
          return attachment.source.to_s if attachment.url?

          attachment.for_llm
        end
      end
    end
  end
end
