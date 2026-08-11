# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Sora video generation jobs on Azure OpenAI. The API lives under
      # the resource's /openai/v1 base and is versioned 'preview' while
      # Sora is in preview.
      module Videos
        API_VERSION = 'preview'

        def video_url
          azure_video_url('video/generations/jobs')
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          { model: model, prompt: prompt }.merge(provider_options)
        end

        def parse_video_job(response, model:)
          id = response.body['id']
          raise Error.new('Azure did not return a video generation job', response:) unless id

          VideoJob.new(id: id, protocol: self, model: model, raw: response.body)
        end

        def video_job_url(job)
          azure_video_url("video/generations/jobs/#{job.id}")
        end

        def parse_video_job_status(response, job:) # rubocop:disable Lint/UnusedMethodArgument
          body = response.body
          case body['status']
          when 'succeeded' then { status: :completed, raw: body }
          when 'failed', 'cancelled'
            { status: :failed, raw: body, error: body['failure_reason'] || body['status'] }
          else { status: :pending, raw: body }
          end
        end

        def download_video(job)
          generation_id = job.raw.dig('generations', 0, 'id')
          raise Error, 'Azure video job has no generations' unless generation_id

          response = @connection.get azure_video_url("video/generations/#{generation_id}/content/video")

          Video.new(
            data: response.body,
            mime_type: response.headers['content-type'] || 'video/mp4',
            model: job.raw['model'] || job.model,
            duration: job.raw['n_seconds'],
            raw: job.raw
          )
        end

        private

        def azure_video_url(path)
          "#{@provider.azure_openai_v1_base}/#{path}?api-version=#{API_VERSION}"
        end
      end
    end
  end
end
