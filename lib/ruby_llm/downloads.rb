# frozen_string_literal: true

require 'tempfile'

module RubyLLM
  # Handles file downloads for providers.
  module Downloads
    DownloadTarget = Struct.new(
      :destination,
      :result,
      :close_after,
      :cleanup_after_block,
      keyword_init: true
    )

    def download_file(file_id, io: nil, path: nil, tempfile: false, &)
      targets = [io, path, (tempfile ? true : nil)].compact
      raise ArgumentError, 'Specify only one of io:, path:, or tempfile: true' if targets.size > 1
      raise ArgumentError, 'Block form is only supported with io: or tempfile: true' if block_given? && path

      target = resolve_download_target(io:, path:, tempfile:)
      return raw_download_response(file_id) unless target

      stream_download_to(download_file_url(file_id), target.destination)
      target.destination.flush if target.destination.respond_to?(:flush)
      target.destination.rewind if target.destination.respond_to?(:rewind)

      finalize_download_result(target, &)
    end

    private

    def resolve_download_target(io:, path:, tempfile:)
      return download_target_for_io(io) if io
      return download_target_for_path(path) if path
      return download_target_for_tempfile if tempfile

      nil
    end

    def download_target_for_io(io)
      DownloadTarget.new(
        destination: io,
        result: io,
        close_after: false,
        cleanup_after_block: false
      )
    end

    def download_target_for_path(path)
      DownloadTarget.new(
        destination: ::File.open(path, 'wb'),
        result: path,
        close_after: true,
        cleanup_after_block: false
      )
    end

    def download_target_for_tempfile
      file = Tempfile.new('ruby_llm-download')
      file.binmode

      DownloadTarget.new(
        destination: file,
        result: file,
        close_after: false,
        cleanup_after_block: true
      )
    end

    def raw_download_response(file_id)
      response = @connection.raw_get(download_file_url(file_id)) do |req|
        req.headers['Accept'] = 'application/octet-stream'
      end
      response.body
    end

    def finalize_download_result(target)
      return target.result unless block_given?

      yield target.result
    ensure
      target.destination.close! if block_given? && target.cleanup_after_block && target.destination.respond_to?(:close!)
      target.destination.close if target.close_after && target.destination.respond_to?(:close)
    end

    def stream_download_to(url, destination)
      destination.binmode if destination.respond_to?(:binmode)

      @connection.raw_get(url) do |req|
        req.headers['Accept'] = 'application/octet-stream'

        if Faraday::VERSION.start_with?('1')
          req.options[:on_data] = proc do |chunk, _overall_received_bytes|
            destination.write(chunk)
          end
        else
          req.options.on_data = proc do |chunk, _overall_received_bytes, env|
            if env&.status == 200
              destination.write(chunk)
            else
              raise_download_error(chunk, env)
            end
          end
        end
      end
    end

    def raise_download_error(chunk, env)
      error_body = try_parse_json(chunk)
      error_response = env.merge(body: error_body)
      ErrorMiddleware.parse_error(provider: self, response: error_response)
    end
  end
end
