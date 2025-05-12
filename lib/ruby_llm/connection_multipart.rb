module RubyLLM
  class ConnectionMultipart < Connection
    def post(url, payload, &)
      @connection.post url, payload do |req|
        req.headers.merge! @provider.headers(@config) if @provider.respond_to?(:headers)
        yield req if block_given?
      end
    end

    def setup_middleware(faraday)
      super
      faraday.request :multipart, content_type: 'multipart/form-data'
    end
  end
end
