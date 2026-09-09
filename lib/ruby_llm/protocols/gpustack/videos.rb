# frozen_string_literal: true

module RubyLLM
  module Protocols
    module GPUStack
      # vLLM-Omni video jobs through GPUStack's model proxy.
      module Videos
        def video_url
          "#{@provider.backend_api_base}/v1/videos"
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          raise ArgumentError, 'vLLM-Omni video generation requires a prompt' if prompt.nil?

          options = video_options(provider_options)
          payload = { model: model, prompt: prompt }.merge(video_references(with)).merge(options).compact
          payload.transform_values do |value|
            value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value
          end
        end

        def post_video(url, payload)
          @connection.post(url, payload, idempotent: false) do |request|
            request.headers['Content-Type'] = 'multipart/form-data'
          end
        end

        def parse_video_job(response, model:)
          body = response.body
          id = body['id']
          raise Error.new('GPUStack did not return a video job id', response:) unless id

          VideoJob.new(id: id, protocol: self, model: body['model'] || model, **video_job_state(body))
        end

        def video_job_url(job)
          "#{video_url}/#{job.id}"
        end

        def parse_video_job_status(response, **)
          video_job_state(response.body)
        end

        def download_video(job)
          response = @connection.get("#{video_job_url(job)}/content")
          Video.new(data: response.body, mime_type: response.headers['content-type'] || job.raw['media_type'],
                    model: job.model, raw: job.raw)
        end

        private

        def video_options(options)
          options = Support::Utils.deep_symbolize_keys(options)
          if options[:num_outputs_per_prompt] && options[:num_outputs_per_prompt] != 1
            raise ArgumentError, 'animate returns one video; num_outputs_per_prompt must be 1'
          end

          options
        end

        def video_references(attachments)
          attachments.group_by(&:type).to_h do |type, group|
            values = group.map { |attachment| { "#{type}_url" => video_reference(attachment) } }
            [:"#{type}_reference", values.one? ? values.first : values]
          end
        end

        def video_job_state(body)
          status = case body['status']
                   when 'queued', 'in_progress' then :pending
                   when 'completed' then :completed
                   when 'failed' then :failed
                   else raise Error, "Unknown GPUStack video status: #{body['status'].inspect}"
                   end
          { status: status, raw: body, error: body.dig('error', 'message') }
        end

        def validate_animate_inputs!(with:)
          @provider.backend_api_base
          with.each do |attachment|
            if attachment.provider_file?
              raise ArgumentError, 'vLLM-Omni video references require media bytes or URLs, not uploaded file ids'
            end
            next if attachment.image? || attachment.video? || attachment.audio?

            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def video_reference(attachment)
          attachment.url? ? attachment.source.to_s : attachment.for_llm
        end
      end
    end
  end
end
