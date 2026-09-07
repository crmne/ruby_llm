# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      class Flows
        module Videos # :nodoc: all
          REFERENCE_VIDEO_MODELS = %w[
            bytedance-seedance-v2 bytedance-seedance-v2-fast bytedance-seedance-v2-mini bytedance-seedance-v2.5
          ].freeze

          def video_url
            'v1/flows/video'
          end

          def render_video_payload(prompt, model:, with: [], provider_options: {})
            payload = if model == 'creatify-aurora'
                        render_character_animation(prompt, with:)
                      else
                        render_video_inputs(prompt, model:, with:)
                      end
            Support::Utils.deep_merge({ model_id: model }.merge(payload), provider_options)
          end

          def render_video_inputs(prompt, model:, with:)
            raise ArgumentError, 'This ElevenLabs video model requires a prompt' if prompt.to_s.empty?

            payload = { prompt: }
            if with.all?(&:image?)
              raise ArgumentError, 'Video generation accepts at most two frame images' if with.size > 2

              payload[:start_frame] = render_media_reference(with[0]) if with[0]
              payload[:end_frame] = render_media_reference(with[1]) if with[1]
            else
              render_video_references(payload, with, model:)
            end
            payload
          end

          def render_character_animation(prompt, with:)
            unless prompt.nil? || prompt.empty?
              raise ArgumentError, 'Creatify Aurora uses image and audio input; omit the prompt'
            end

            image = with.select(&:image?)
            audio = with.select(&:audio?)
            unless with.size == 2 && image.one? && audio.one?
              raise ArgumentError, 'Creatify Aurora requires exactly one image and one audio attachment'
            end

            { image: render_media_reference(image.first), audio: render_media_reference(audio.first) }
          end

          def render_video_references(payload, attachments, model:)
            unless REFERENCE_VIDEO_MODELS.include?(model)
              raise ArgumentError, 'This ElevenLabs video model only accepts image attachments'
            end

            { images: :image?, audios: :audio?, videos: :video? }.each do |field, predicate|
              references = attachments.select { |attachment| attachment.public_send(predicate) }
              payload[field] = references.map { |attachment| render_media_reference(attachment) } if references.any?
            end
          end

          def parse_video_job(response, model:)
            VideoJob.new(id: response.body.fetch('id'), protocol: self, model:, raw: response.body)
          end

          def video_job_url(job)
            "#{video_url}/#{job.id}"
          end

          def parse_video_job_status(response, **)
            parse_generation_status(response.body)
          end

          def download_video(job)
            Video.new(url: job.raw.fetch('content_url'), mime_type: job.raw.fetch('content_mime_type'),
                      model: job.model, raw: job.raw)
          end

          def validate_animate_inputs!(with:)
            with.each do |attachment|
              unless attachment.image? || attachment.audio? || attachment.video?
                raise UnsupportedAttachmentError, attachment.mime_type
              end
            end
          end
        end
      end
    end
  end
end
