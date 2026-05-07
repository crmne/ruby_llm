# frozen_string_literal: true

require 'tempfile'

module RubyLLM
  # Handles file downloads for providers.
  module Downloads
    def download_file(file_id, io: nil, path: nil, tempfile: false, &)
      targets = [io, path, (tempfile ? true : nil)].compact
      raise ArgumentError, 'Specify only one of io:, path:, or tempfile: true' if targets.size > 1
      raise ArgumentError, 'Block form is only supported with io: or tempfile: true' if block_given? && path

      destination, return_value, close_after, cleanup_after_block = build_download_destination(io:, path:, tempfile:)

      if destination
        stream_download_to(download_file_url(file_id), destination)
        destination.flush if destination.respond_to?(:flush)
        destination.rewind if destination.respond_to?(:rewind)

        return finalize_download_result(destination, return_value, close_after:, cleanup_after_block:, &)
      end

      response = @connection.raw_get(download_file_url(file_id)) do |req|
        req.headers['Accept'] = 'application/octet-stream'
      end
      response.body
    end

    private

    def build_download_destination(io:, path:, tempfile:)
      return [io, io, false, false] if io

      return [::File.open(path, 'wb'), path, true, false] if path

      if tempfile
        file = Tempfile.new('ruby_llm-download')
        file.binmode
        return [file, file, false, true]
      end

      [nil, nil, false, false]
    end

    def finalize_download_result(destination, return_value, close_after:, cleanup_after_block:)
      return return_value unless block_given?

      yield return_value
    ensure
      destination.close! if cleanup_after_block && destination.respond_to?(:close!)
      destination.close if close_after && destination.respond_to?(:close)
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
