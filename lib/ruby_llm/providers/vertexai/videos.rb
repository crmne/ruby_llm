# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Veo prediction jobs with inline or Cloud Storage video output.
      module Videos
        def video_url
          "#{@provider.model_path(model_id(@model))}:predictLongRunning"
        end

        def video_job_url(job)
          "#{job.id.split('/operations/').first}:fetchPredictOperation"
        end

        def refresh_video_job(job)
          response = @connection.post video_job_url(job), { operationName: job.id }
          parse_video_job_status(response, job:)
        end

        def download_video(job)
          video = generated_video(job.raw)
          raise Error, 'Vertex AI returned no video' unless video

          data = if video['bytesBase64Encoded']
                   Base64.decode64(video['bytesBase64Encoded'])
                 else
                   @provider.download_file(video.fetch('gcsUri'))
                 end

          Video.new(data:, mime_type: video['mimeType'] || 'video/mp4', model: job.model, raw: job.raw)
        end

        private

        def render_video_extension(source)
          uri = source.respond_to?(:uri) ? source.uri : source
          return { gcsUri: uri, mimeType: 'video/mp4' } if uri.is_a?(String) && uri.start_with?('gs://')

          video = video_extension_attachment(source)
          { bytesBase64Encoded: video.encoded, mimeType: video.mime_type }
        end

        def render_video_image(image)
          { bytesBase64Encoded: image.encoded, mimeType: image.mime_type }
        end

        def generated_video(body)
          video = body.dig('response', 'videos', 0)
          video if video && %w[bytesBase64Encoded gcsUri].any? { |key| !video[key].to_s.empty? }
        end

        def filtered_video_failure(body)
          error = Array(body.dig('response', 'raiMediaFilteredReasons')).join(' ')
          error = 'Vertex AI returned no video' if error.empty?
          { status: :failed, raw: body, error: }
        end
      end
    end
  end
end
