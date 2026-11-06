# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      # Gemini Omni video generation. A background interaction is the only way
      # Gemini lets a job be polled, and it requires store: true, so the job
      # stays on Google's servers. Each job is a single turn, not a conversation.
      module Videos # :nodoc:
        JOB_ID = /\A[\w-]+\z/
        FINISHED_WITHOUT_VIDEO = %w[failed cancelled incomplete budget_exceeded].freeze
        private_constant :JOB_ID, :FINISHED_WITHOUT_VIDEO

        def video_url
          'interactions'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {}, **)
          text = prompt.to_s.empty? ? [] : [{ type: 'text', text: prompt.to_s }]
          payload = { model:, input: with.map { |attachment| render_interaction_attachment(attachment) } + text,
                      background: true, store: true, response_format: { type: 'video' } }

          Support::Utils.deep_merge(payload, provider_options)
        end

        # Gemini refuses uploaded sources in some regions but continues a
        # video it generated everywhere, so a generated Video names its job.
        def render_video_extension_payload(prompt, extend:, model:, provider_options: {}, **)
          generated = extend.is_a?(Video) && extend.raw && generated_video(extend.raw)
          unless generated
            return render_video_payload(prompt, model:, with: [video_extension_attachment(extend)],
                                                provider_options:)
          end

          render_video_payload(prompt, model:, provider_options:).merge(previous_interaction_id: extend.raw['id'])
        end

        def video_request_settings(request)
          request[:response_format].slice(:duration, :resolution)
        end

        def parse_video_job(response, model:, **request)
          id = response.body['id']
          raise Error.new('Gemini did not return a video generation interaction', response:) unless id

          VideoJob.new(id:, protocol: self, model:, **request, **parse_video_job_status(response))
        end

        def video_job_url(job)
          return "interactions/#{job.id}" if job.id.match?(JOB_ID)

          raise ArgumentError, "#{job.id.inspect} is not a video interaction id"
        end

        def parse_video_job_status(response, **)
          body = response.body
          return { status: :pending, raw: body } unless finished_video_job?(body)

          tokens = Tokens.new(**parse_video_tokens(body))
          return { status: :completed, raw: body, tokens: } if body['status'] == 'completed' && generated_video(body)

          { status: :failed, raw: body, tokens:, error: video_job_error(body) }
        end

        def download_video(job)
          video = generated_video(job.raw)

          Video.new(data: Base64.decode64(video['data']), mime_type: video['mime_type'] || 'video/mp4',
                    model: job.raw['model'] || job.model, raw: job.raw)
        end

        private

        def validate_animate_inputs!(with:); end

        def finished_video_job?(body)
          body['status'] == 'completed' || FINISHED_WITHOUT_VIDEO.include?(body['status'])
        end

        def parse_video_tokens(body)
          usage = parse_interaction_usage(body['usage'] || {})
          { input: usage[:input_tokens], output: usage[:output_tokens], cache_read: usage[:cache_read_tokens],
            thinking: usage[:thinking_tokens] }
        end

        def video_job_error(body)
          message = Array(body['errors']).filter_map { |error| error['message'] }.join('; ')
          message.empty? ? 'Gemini returned no video' : message
        end

        def generated_video(body)
          Array(body['steps']).select { |step| step['type'] == 'model_output' }
                              .flat_map { |step| Array(step['content']) }
                              .find { |part| part['type'] == 'video' && part['data'] }
        end
      end
    end
  end
end
