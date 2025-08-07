# frozen_string_literal: true

module RubyLLM
  # A connection that uses multipart/form-data for file uploads
  class ConnectionMultipart < Connection
    def post(url, payload, &)
      @connection.post url, payload do |req|
        req.headers.merge! @provider.headers if @provider.respond_to?(:headers)
        req.headers['Content-Type'] = 'multipart/form-data'
        yield req if block_given?
      end
    end

    def setup_middleware(faraday)
      super
      faraday.request :multipart, content_type: 'multipart/form-data'
    end
  end
end
