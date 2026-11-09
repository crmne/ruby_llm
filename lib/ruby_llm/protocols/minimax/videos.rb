# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # Asynchronous video generation on v2/video_generation. The endpoint
      # requires a resolution and duration, and a ratio for text-only
      # requests, so those are defaulted to values every MiniMax-H3 variant
      # takes. A single image is the first frame; other attachments are
      # references.
      module Videos
        DEFAULT_SETTINGS = { resolution: '768P', duration: 5 }.freeze
        DEFAULT_RATIO = '16:9'
        UNTYPED_MIME_TYPES = [nil, 'application/octet-stream'].freeze
        REFERENCE_KINDS = { image: :image_url, video: :video_url, audio: :audio_url }.freeze

        def video_url
          media_url('v2/video_generation')
        end

        def video_job_url(job)
          media_url("v2/query/video_generation/#{job.id}")
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          payload = { model: model, content: [{ type: 'text', text: prompt }] + video_references(with) }
          payload.merge!(DEFAULT_SETTINGS)
          payload[:ratio] = DEFAULT_RATIO if with.empty?
          Support::Utils.deep_merge(payload, provider_options)
        end

        def parse_video_job(response, model:, **request)
          id = response.body['task_id']
          raise Error.new('MiniMax did not return a video task id', response:) unless id

          VideoJob.new(id: id.to_s, protocol: self, model: model, raw: response.body, **request)
        end

        def parse_video_job_status(response, **)
          task = response.body['task']
          raise Error.new('MiniMax did not return a video task', response:) unless task

          state = case task['status']
                  when 'succeeded' then { status: :completed }
                  when 'failed' then { status: :failed, error: task.dig('error', 'message') || 'failed' }
                  else { status: :pending }
                  end
          state.merge(raw: response.body)
        end

        def download_video(job)
          task = job.raw['task'] || {}
          Video.new(url: task.dig('content', 'url'), mime_type: 'video/mp4', duration: task['duration'],
                    model: task['model'] || job.model, raw: job.raw)
        end

        private

        def validate_animate_inputs!(with:)
          with.each do |attachment|
            next if reference_kind(attachment) || UNTYPED_MIME_TYPES.include?(attachment.mime_type)

            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def video_references(attachments)
          first_frame = attachments.one? && reference_kind_or_image(attachments.first) == :image
          attachments.map do |attachment|
            kind = reference_kind_or_image(attachment)
            part = REFERENCE_KINDS.fetch(kind)
            { type: part.to_s, part => { url: video_reference_url(attachment) },
              role: first_frame ? 'first_frame' : "reference_#{kind}" }
          end
        end

        def reference_kind(attachment)
          %i[image video audio].find { |kind| attachment.public_send(:"#{kind}?") }
        end

        def reference_kind_or_image(attachment)
          reference_kind(attachment) || :image
        end

        def video_reference_url(attachment)
          return "mm_file://#{attachment.provider_file_id}" if attachment.provider_file?

          attachment.url_or_data_uri
        end
      end
    end
  end
end
