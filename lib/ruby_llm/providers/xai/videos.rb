# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Grok Imagine generation, editing, and extension jobs.
      module Videos
        def video_url
          'videos/generations'
        end

        def video_request_url(payload)
          payload.key?(:video) ? 'videos/edits' : video_url
        end

        def video_extension_url
          'videos/extensions'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          payload = { model: model, prompt: prompt }
          if (attachment = with.first)
            key = attachment.video? ? :video : :image
            payload[key] = video_reference(attachment)
          end

          payload.merge(provider_options)
        end

        def render_video_extension_payload(prompt, model:, extend:, provider_options: {})
          video = video_extension_attachment(extend)
          { model: model, prompt: prompt, video: video_reference(video) }.merge(provider_options)
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
          raise Error, 'xAI video generation takes a single reference image or video' if with.size > 1

          with.each do |attachment|
            next if attachment.provider_file? || attachment.url?
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image? || attachment.video?
          end
        end

        def video_reference(attachment)
          return { file_id: attachment.provider_file_id } if attachment.provider_file?
          return { url: attachment.source.to_s } if attachment.url?

          { url: attachment.for_llm }
        end
      end
    end
  end
end
