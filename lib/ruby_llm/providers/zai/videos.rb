# frozen_string_literal: true

module RubyLLM
  module Providers
    class ZAI
      # CogVideoX jobs. Reference images are the first frame, or the first
      # and last frames, as URLs or data URIs. Job states come from the
      # async-result endpoint, and finished videos are hosted by Z.ai.
      module Videos
        MAX_VIDEO_IMAGES = 2
        private_constant :MAX_VIDEO_IMAGES

        def video_url
          'videos/generations'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          payload = { model:, prompt: }.compact
          payload[:image_url] = with.map(&:url_or_data_uri) if with.any?
          payload.merge(provider_options)
        end

        def parse_video_job(response, model:, **request)
          id = response.body['id']
          raise Error.new('Z.ai did not return a video job id', response:) unless id

          VideoJob.new(id:, protocol: self, model:, raw: response.body, **request)
        end

        def video_request_settings(request)
          { duration: request[:duration], resolution: request[:size] }
        end

        def video_job_url(job)
          "async-result/#{job.id}"
        end

        def parse_video_job_status(response, **)
          body = response.body
          case body['task_status']
          when 'SUCCESS' then { status: :completed, raw: body }
          when 'FAIL' then { status: :failed, raw: body, error: 'Z.ai could not generate the video' }
          else { status: :pending, raw: body }
          end
        end

        def download_video(job)
          url = job.raw.dig('video_result', 0, 'url')
          raise Error, 'Z.ai video job has no video' unless url

          Video.new(url:, mime_type: 'video/mp4', model: job.raw['model'] || job.model, raw: job.raw)
        end

        private

        def validate_animate_inputs!(with:)
          raise Error, 'Z.ai takes at most a first and a last frame' if with.size > MAX_VIDEO_IMAGES

          with.each do |attachment|
            next if attachment.url?
            raise UnsupportedAttachmentError, attachment.mime_type if attachment.provider_file? || !attachment.image?
          end
        end
      end
    end
  end
end
