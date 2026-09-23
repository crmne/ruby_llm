# frozen_string_literal: true

module RubyLLM
  class MCP
    # Streamable HTTP. Every message is its own POST, answered with a JSON
    # body or with an event stream that carries the request's notifications
    # before its response. Plain HTTP is only allowed on loopback addresses,
    # and redirects are never followed.
    class HTTP # :nodoc:
      LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
      HEADER_SAFE = /\A[\x21-\x7E](?:[\x20-\x7E]*[\x21-\x7E])?\z/
      ENCODED_HEADER = /\A=\?base64\?.*\?=\z/

      def initialize(url, headers: {}, timeout: nil, config: RubyLLM.config)
        @url = URI(url)
        raise ArgumentError, "MCP servers must use HTTPS: #{url}" unless secure?

        @headers = headers
        @connection = Transport::Connection.basic(config) do |faraday|
          faraday.options.timeout = timeout if timeout
        end
      end

      def request(message, version:, timeout: nil, &)
        replies = post(message, version:, timeout:, &)
        replies.find { |reply| reply['id'] == message[:id] } ||
          raise(Error, "#{@url.host} did not answer #{message[:method]}")
      end

      def notify(message, version:)
        post(message, version:)
        nil
      end

      def close
        @session = nil
      end

      private

      def post(message, version:, timeout: nil, &on_notification)
        stream = Stream.new(&on_notification)
        response = @connection.post(@url) do |request|
          request.headers.update(headers(message, version))
          request.body = JSON.generate(message)
          request.options.timeout = timeout if timeout
          request.options.on_data = stream.method(:feed).to_proc
        end
        @session = response.headers['mcp-session-id'] if message[:method] == 'initialize'
        stream.replies
      rescue Faraday::Error => e
        raise unless e.response

        raise failure(e.response, stream)
      end

      def headers(message, version)
        {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json, text/event-stream',
          'MCP-Protocol-Version' => version,
          'Mcp-Session-Id' => @session,
          'Mcp-Method' => message[:method],
          'Mcp-Name' => header_value(message.dig(:params, :name) || message.dig(:params, :uri))
        }.compact.merge(@headers.respond_to?(:call) ? @headers.call : @headers)
      end

      def header_value(value)
        return if value.nil?

        value = value.to_s
        return value if value.match?(HEADER_SAFE) && !value.match?(ENCODED_HEADER)

        "=?base64?#{Base64.strict_encode64(value)}?="
      end

      def failure(response, stream)
        case response[:status]
        when 401 then UnauthorizedError.new("#{@url.host} requires authorization", response: response_for(response))
        when 403 then ForbiddenError.new("#{@url.host} refused the request", response: response_for(response))
        else
          error = stream.replies.first&.fetch('error', nil) || {}
          Error.new(error['message'] || "#{@url.host} answered HTTP #{response[:status]}",
                    code: error['code'], data: error['data'], response: response_for(response))
        end
      end

      def response_for(response)
        Faraday::Response.new(status: response[:status], response_headers: response[:headers],
                              body: response[:body])
      end

      def secure?
        @url.scheme == 'https' || (@url.scheme == 'http' && LOOPBACK_HOSTS.include?(@url.hostname))
      end

      # Collects the JSON-RPC messages of one response, yielding
      # notifications as they arrive. The body is either a single JSON value
      # or a server-sent event stream; the first character tells them apart.
      class Stream # :nodoc:
        def initialize(&on_notification)
          @on_notification = on_notification
          @parser = EventStreamParser::Parser.new
          @body = +''
          @replies = []
        end

        def feed(chunk, *)
          @body << chunk
          return if @events == false

          if @events.nil?
            return if @body.strip.empty?

            @events = !@body.lstrip.start_with?('{', '[')
            chunk = @body
          end
          @parser.feed(chunk) { |_type, data| receive(data) } if @events
        end

        def replies
          receive(@body) if @events == false && @replies.empty?
          @replies
        end

        private

        def receive(data)
          parsed = JSON.parse(data)
          (parsed.is_a?(Array) ? parsed : [parsed]).each do |reply|
            @replies << reply
            @on_notification&.call(reply) if reply['method'] && !reply.key?('id')
          end
        rescue JSON::ParserError
          RubyLLM.logger.debug { 'MCP server sent a message that is not JSON' }
        end
      end
    end
  end
end
