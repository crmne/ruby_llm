# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # MiniMax asynchronous video generation. The v2 endpoint takes a
      # multimodal content array and reports a hosted URL on the finished
      # task, while the v1 endpoint takes a flat prompt and reports a file id
      # that has to be retrieved before the clip can be downloaded. Both are
      # submit-then-poll, so the model id picks the version for every step of
      # a job's lifecycle.
      module Videos
        V2_MODELS = %w[MiniMax-H3].freeze
        V1_MODELS = %w[
          MiniMax-Hailuo-2.3
          MiniMax-Hailuo-2.3-Fast
          MiniMax-Hailuo-02
          T2V-01-Director
          T2V-01
          I2V-01-Director
          I2V-01-live
          I2V-01
        ].freeze
        MODELS = (V2_MODELS + V1_MODELS).freeze
        DEFAULT_RESOLUTION = '2K'
        DEFAULT_DURATION = 4
        MAX_PROMPT_CHARACTERS = 7000

        def video_url
          video_api_url(@model, 'video_generation')
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {}) # rubocop:disable Lint/UnusedMethodArgument
          payload = if v2_video_model?(model)
                      render_v2_video_payload(prompt, model)
                    else
                      { model: model, prompt: prompt }
                    end

          Utils.deep_merge(payload, provider_options)
        end

        def parse_video_job(response, model:)
          body = response.body
          if (error = video_response_error(body))
            raise Error.new(error, response:)
          end

          id = body['task_id']
          raise Error.new('MiniMax did not return a video generation task id', response:) unless id

          VideoJob.new(id: id, protocol: self, model: model, raw: body)
        end

        def video_job_url(job)
          return video_api_url(job.model, "query/video_generation/#{job.id}") if v2_video_model?(job.model)

          video_api_url(job.model, "query/video_generation?task_id=#{job.id}")
        end

        def parse_video_job_status(response, job:)
          body = response.body
          return parse_v2_video_job_status(body) if v2_video_model?(job.model)

          parse_v1_video_job_status(body)
        end

        def download_video(job)
          return v2_video(job) if v2_video_model?(job.model)

          v1_video(job)
        end

        private

        def render_v2_video_payload(prompt, model)
          if prompt.to_s.length > MAX_PROMPT_CHARACTERS
            raise Error, "MiniMax video prompts are limited to #{MAX_PROMPT_CHARACTERS} characters"
          end

          {
            model: model,
            content: [{ type: 'text', text: prompt }],
            resolution: DEFAULT_RESOLUTION,
            duration: DEFAULT_DURATION
          }
        end

        def parse_v2_video_job_status(body)
          task = body['task'] || {}
          case task['status']
          when 'succeeded' then { status: :completed, raw: body }
          when 'failed', 'cancelled' then { status: :failed, raw: body, error: v2_video_error(task) }
          else { status: :pending, raw: body }
          end
        end

        def parse_v1_video_job_status(body)
          if (error = video_response_error(body))
            return { status: :failed, raw: body, error: error }
          end

          case body['status']
          when 'Success' then { status: :completed, raw: body }
          when 'Fail' then { status: :failed, raw: body, error: body['status'] }
          else { status: :pending, raw: body }
          end
        end

        def v2_video(job)
          task = job.raw['task'] || {}
          url = task.dig('content', 'url')
          raise Error, 'MiniMax video task has no output url' unless url

          Video.new(
            url: url,
            mime_type: 'video/mp4',
            model: task['model'] || job.model,
            duration: task['duration'],
            raw: job.raw
          )
        end

        def v1_video(job)
          file_id = job.raw['file_id']
          raise Error, 'MiniMax video task has no output file id' unless file_id

          body = @connection.get(video_api_url(job.model, "files/retrieve?file_id=#{file_id}")).body
          error = video_response_error(body)
          raise Error, error if error

          url = body.dig('file', 'download_url')
          raise Error, 'MiniMax did not return a video download url' unless url

          Video.new(url: url, mime_type: 'video/mp4', model: job.model, raw: job.raw)
        end

        def v2_video_error(task)
          error = task['error']
          return error unless error.is_a?(Hash)

          error['message'] || error['code']
        end

        # MiniMax reports request-level failures in base_resp with a non-zero
        # status code, even when the HTTP status is 200.
        def video_response_error(body)
          return unless body.is_a?(Hash)

          status = body.dig('base_resp', 'status_code')
          return if status.nil? || status.to_i.zero?

          ["MiniMax video request failed with status #{status}", body.dig('base_resp', 'status_msg')]
            .compact.join(': ')
        end

        # Models outside the v2 catalog stay on v1, which is where MiniMax
        # keeps every model that predates the v2 request schema.
        def v2_video_model?(model)
          V2_MODELS.include?(video_model_id(model))
        end

        def video_model_id(model)
          model.respond_to?(:id) ? model.id : model.to_s
        end

        def video_api_url(model, path)
          "#{@provider.video_api_base(v2_video_model?(model) ? 'v2' : 'v1')}/#{path}"
        end
      end
    end
  end
end
