# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # OpenRouter's asynchronous video generation API. Reference images
      # become frame_images entries, and finished videos are downloaded
      # from the job's authenticated content endpoint.
      module Videos
        FRAME_TYPES = %w[first_frame last_frame].freeze

        def video_url
          'videos'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          payload = { model: model, prompt: prompt }
          payload[:frame_images] = frame_images(with) if with.any?

          payload.merge(provider_options)
        end

        def parse_video_job(response, model:)
          id = response.body['id']
          raise Error.new('OpenRouter did not return a video job', response:) unless id

          VideoJob.new(id: id, protocol: self, model: model, status: job_status(response.body), raw: response.body)
        end

        def video_job_url(job)
          "videos/#{job.id}"
        end

        def parse_video_job_status(response, job:) # rubocop:disable Lint/UnusedMethodArgument
          body = response.body
          status = job_status(body)
          state = { status: status, raw: body }
          state[:error] = body['error'] || body['status'] if status == :failed
          state
        end

        def download_video(job)
          response = @connection.get "videos/#{job.id}/content?index=0"

          Video.new(
            data: response.body,
            mime_type: response.headers['content-type'] || 'video/mp4',
            model: job.model,
            raw: job.raw
          )
        end

        private

        def job_status(body)
          case body['status']
          when 'completed' then :completed
          when 'failed' then :failed
          else :pending
          end
        end

        def validate_animate_inputs!(with:)
          raise Error, 'OpenRouter video generation takes at most first and last frame images' if with.size > 2

          with.each do |attachment|
            next if attachment.url?
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          end
        end

        def frame_images(attachments)
          attachments.zip(FRAME_TYPES).map do |attachment, frame_type|
            url = attachment.url? ? attachment.source.to_s : attachment.for_llm
            { type: 'image_url', image_url: { url: url }, frame_type: frame_type }
          end
        end
      end
    end
  end
end
