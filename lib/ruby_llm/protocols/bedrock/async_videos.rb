# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Bedrock
      # Luma Ray 2 video generation through Bedrock asynchronous invocation.
      class AsyncVideos < Protocol
        def video_url
          '/async-invoke'
        end

        def render_video_payload(prompt, model:, with: [], provider_options: {})
          output_uri = video_output_uri
          options = Support::Utils.deep_symbolize_keys(provider_options)
          outer = options.slice(:clientRequestToken, :tags)
          input = { prompt: prompt }.merge(render_keyframes(with)).merge(options.except(*outer.keys))
          { modelId: model, modelInput: input, clientRequestToken: SecureRandom.uuid,
            outputDataConfig: { s3OutputDataConfig: { s3Uri: output_uri } } }.merge(outer)
        end

        def post_video(url, payload)
          body = JSON.generate(payload)
          @connection.post(url, body, idempotent: false) do |request|
            request.headers.merge!(@provider.sign_headers('POST', url, body))
          end
        end

        def parse_video_job(response, model:)
          id = response.body['invocationArn']
          raise Error.new('Bedrock did not return a video invocation ARN', response:) unless id

          VideoJob.new(id: id, protocol: self, model: model, raw: response.body)
        end

        def video_job_url(job)
          "/async-invoke/#{URI.encode_www_form_component(job.id)}"
        end

        def refresh_video_job(job)
          url = video_job_url(job)
          response = @connection.get(url) do |request|
            request.headers.merge!(@provider.sign_headers('GET', url, ''))
          end
          parse_video_job_status(response, job:)
        end

        def parse_video_job_status(response, **)
          body = response.body
          status = case body['status']
                   when 'InProgress' then :pending
                   when 'Completed' then :completed
                   when 'Failed' then :failed
                   else raise Error.new("Unknown Bedrock video status: #{body['status'].inspect}", response:)
                   end
          { status: status, raw: body, error: body['failureMessage'] }
        end

        def download_video(job)
          prefix = job.raw.dig('outputDataConfig', 's3OutputDataConfig', 's3Uri')
          raise Error, 'Bedrock video job has no output S3 URI' unless prefix

          prefix_length = (prefix.rindex(%r{[^/]}) || -1) + 1
          uris = @provider.list_file_uris("#{prefix[0, prefix_length]}/")
          videos = uris.select { |uri| uri.downcase.end_with?('.mp4') }
          raise Error, 'Expected exactly one MP4 in the Bedrock video output' unless videos.one?

          Video.new(data: @provider.download_file(videos.first), mime_type: 'video/mp4', model: job.model, raw: job.raw)
        end

        private

        def video_output_uri
          uri = @config.bedrock_video_s3_uri
          unless uri&.match?(%r{\As3://[a-z0-9][.\-a-z0-9]{1,61}[a-z0-9]/[^?#]+\z})
            raise ConfigurationError, 'Set bedrock_video_s3_uri to the intended s3://bucket/output-prefix'
          end

          uri
        end

        def validate_animate_inputs!(with:)
          raise ArgumentError, 'Luma Ray 2 accepts at most two reference images' if with.length > 2

          with.each do |attachment|
            if attachment.provider_file?
              raise ArgumentError, 'Luma Ray 2 requires image bytes or URLs, not uploaded file ids'
            end

            raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          end
        end

        def render_keyframes(attachments)
          return {} if attachments.empty?

          frames = attachments.each_with_index.to_h do |attachment, index|
            ["frame#{index}", { type: 'image', source: { type: 'base64', media_type: attachment.mime_type,
                                                         data: attachment.encoded } }]
          end
          { keyframes: frames }
        end
      end
    end
  end
end
