# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Veo video generation through the Gemini API's long-running predict
      # operations. The finished video is a Files API URI that requires the
      # API key to download.
      module Videos
        def video_url
          "models/#{model_id(@model)}:predictLongRunning"
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          instance = { prompt: prompt }
          if (image = with.first)
            instance[:image] = { inlineData: { mimeType: image.mime_type, data: image.encoded } }
          end

          Utils.deep_merge({ instances: [instance] }, provider_options)
        end

        def parse_video_job(response, model:)
          name = response.body['name']
          raise Error.new('Gemini did not return a video generation operation', response:) unless name

          VideoJob.new(id: name, protocol: self, model: model, raw: response.body)
        end

        def video_job_url(job)
          job.id
        end

        def parse_video_job_status(response, job:) # rubocop:disable Lint/UnusedMethodArgument
          body = response.body
          if body['error']
            { status: :failed, raw: body, error: body.dig('error', 'message') }
          elsif body['done']
            video = generated_video(body)
            video ? { status: :completed, raw: body } : filtered_video_failure(body)
          else
            { status: :pending, raw: body }
          end
        end

        # The file URI answers with a redirect to the download host, and
        # both hops require the API key.
        def download_video(job)
          video = generated_video(job.raw)
          response = @connection.get video['uri']
          response = @connection.get response.headers['location'] if response.status / 100 == 3

          Video.new(
            data: response.body,
            mime_type: video['mimeType'] || 'video/mp4',
            model: job.model,
            raw: job.raw
          )
        end

        private

        def validate_animate_inputs!(with:)
          raise Error, 'Veo takes a single reference image' if with.size > 1

          with.each do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          end
        end

        def generated_video(body)
          body.dig('response', 'generateVideoResponse', 'generatedSamples', 0, 'video')
        end

        def filtered_video_failure(body)
          reasons = body.dig('response', 'generateVideoResponse', 'raiMediaFilteredReasons')
          error = Array(reasons).join(' ')
          error = 'Gemini returned no video' if error.empty?
          { status: :failed, raw: body, error: error }
        end
      end
    end
  end
end
