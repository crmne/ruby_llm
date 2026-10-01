# frozen_string_literal: true

module RubyLLM
  class MCP
    # Streamable HTTP. Every message is its own POST, answered with a JSON
    # body or with an event stream that carries the request's notifications
    # before its response. Plain HTTP is only allowed on loopback addresses,
    # URLs cannot carry credentials, and redirects are never followed. A cancelled chat closes the stream,
    # which is how 2026-07-28 cancels a request. Servers that predate it may
    # keep a session, which ends with a DELETE when the transport closes.
    #
    # When a stream ends before the response, 2026-07-28 sends the request
    # again with a new ID, while older servers resume the stream from its
    # last event ID after the wait they ask for, a few times at most.
    class HTTP # :nodoc:
      LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
      HEADER_SAFE = /\A[\x21-\x7E](?:[\x20-\x7E]*[\x21-\x7E])?\z/
      ENCODED_HEADER = /\A=\?base64\?.*\?=\z/
      CLOSE_TIMEOUT = 5
      RECONNECTS = 3
      RECONNECT_DELAY = 1
      CHECK_INTERVAL = 0.1

      # Raised when a server has ended the session a request belonged to.
      class SessionExpired < Error; end

      def self.secure?(url)
        uri = URI(url.to_s)
        return false if uri.userinfo

        uri.scheme == 'https' || (uri.scheme == 'http' && loopback?(uri))
      end

      def self.loopback?(url)
        LOOPBACK_HOSTS.include?(URI(url.to_s).hostname)
      end

      def initialize(url, headers: {}, timeout: nil, unauthorized: nil, config: RubyLLM.config)
        @url = URI(url)
        unless self.class.secure?(@url)
          raise ArgumentError, "MCP servers must use HTTPS without credentials in the URL: #{url}"
        end

        @headers = headers
        @unauthorized = unauthorized
        @timeout = timeout || config.request_timeout
        @connection = Transport::Connection.basic(config) do |faraday|
          faraday.options.timeout = timeout if timeout
          faraday.adapter config.faraday_adapter
        end
      end

      def request(message, version:, timeout: nil, headers: {}, &)
        stream = post(message, version:, timeout:, params: headers, &)
        RECONNECTS.times do
          if version == Client::VERSION
            break unless stream.interrupted?

            stream = post(message.merge(id: SecureRandom.uuid), version:, timeout:, params: headers, &)
          else
            break unless resumable?(stream, timeout || @timeout)

            stream = resume(stream, version:, timeout:, &)
          end
        end
        stream.answer || raise(Error, "#{@url.host} did not answer #{message[:method]}")
      end

      def notify(message, version:)
        post(message, version:)
        nil
      end

      def cancel(notification, version:)
        notify(notification, version:) unless version == Client::VERSION
      end

      def close
        session = @session
        @session = nil
        return unless session

        @connection.delete(@url) do |request|
          request.headers.update({ 'MCP-Protocol-Version' => @version, 'Mcp-Session-Id' => session }.compact)
          request.headers.update(custom_headers)
          request.options.timeout = CLOSE_TIMEOUT
        end
      rescue Faraday::Error
        nil
      end

      private

      def post(message, version:, timeout: nil, params: {}, retried: false, &on_notification)
        session = @session unless message[:method] == 'initialize'
        stream = Stream.new(message[:id], &on_notification)
        stream.read do
          @connection.post(@url) do |request|
            request.headers.update(headers(message, version, session))
            params.each { |name, value| request.headers["Mcp-Param-#{name}"] = header_value(value) }
            request.body = JSON.generate(message)
            stream.attach(request, timeout)
          end
        end
        remember(message, version, stream.headers)
        stream
      rescue Faraday::Error => e
        raise unless e.response
        return stream if answered?(stream)
        raise SessionExpired, "#{@url.host} ended the session" if expired?(e.response, message, session)

        if reauthorized?(e.response, retried)
          return post(message, version:, timeout:, params:, retried: true, &on_notification)
        end

        raise failure(e.response, stream)
      end

      def resume(stream, version:, timeout:, &on_notification)
        wait(stream.retry_after || RECONNECT_DELAY)
        resumed = Stream.new(stream.id, &on_notification)
        resumed.read do
          @connection.get(@url) do |request|
            request.headers.update({ 'Accept' => 'text/event-stream', 'MCP-Protocol-Version' => version,
                                     'Mcp-Session-Id' => @session, 'Last-Event-ID' => stream.last_event_id }.compact)
            request.headers.update(custom_headers)
            resumed.attach(request, timeout)
          end
        end
      rescue Faraday::Error
        resumed
      end

      def resumable?(stream, limit)
        stream.interrupted? && stream.last_event_id && (limit.nil? || (stream.retry_after || 0) <= limit)
      end

      def wait(seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        loop do
          Support::Cancellation.check
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break unless remaining.positive?

          sleep [remaining, CHECK_INTERVAL].min
        end
      end

      def remember(message, version, headers)
        @version = version if version
        @session = headers['mcp-session-id'] if message[:method] == 'initialize'
      end

      def expired?(response, message, session)
        session && message[:id] && response[:status] == 404
      end

      # Some servers, such as Google's Drive preview, send a complete
      # JSON-RPC result with an error status. The result is the answer.
      def answered?(stream)
        stream.answer&.key?('result')
      end

      def reauthorized?(response, retried)
        status = response[:status]
        return false unless @unauthorized && (status == 403 || (status == 401 && !retried))

        @unauthorized.call(response[:headers] || {}, status) && status == 401
      end

      def headers(message, version, session)
        {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json, text/event-stream',
          'MCP-Protocol-Version' => version,
          'Mcp-Session-Id' => session,
          'Mcp-Method' => message[:method],
          'Mcp-Name' => header_value(message.dig(:params, :name) || message.dig(:params, :uri))
        }.compact.merge(custom_headers)
      end

      def custom_headers
        @headers.respond_to?(:call) ? @headers.call : @headers
      end

      def header_value(value)
        return if value.nil?

        value = value.to_s
        return value if value.empty? || (value.match?(HEADER_SAFE) && !value.match?(ENCODED_HEADER))

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

      # Collects the JSON-RPC messages of one response, yielding
      # notifications as they arrive. The body is either a single JSON value
      # or a server-sent event stream; the first character tells them apart.
      # An event stream stops being read once it carries the answer to
      # request +id+, since servers may keep it open, and one that breaks
      # midway counts as ended.
      class Stream # :nodoc:
        attr_reader :id, :headers

        def initialize(id, &on_notification)
          @id = id
          @on_notification = on_notification
          @parser = Transport::EventStreamParser.new
          @body = +''
          @replies = []
          @headers = {}
        end

        def attach(request, timeout)
          request.options.timeout = timeout if timeout
          request.options.on_data = method(:feed).to_proc
        end

        def read(&)
          catch(self, &)
          self
        rescue Faraday::ConnectionFailed
          raise unless events?

          self
        end

        def feed(chunk, _size = nil, env = nil)
          Support::Cancellation.check
          @headers = env.response_headers if env&.response_headers
          @body << chunk
          return if @events == false

          if @events.nil?
            return if @body.strip.empty?

            @events = !@body.lstrip.start_with?('{', '[')
            chunk = @body
          end
          return unless @events

          @parser.feed(chunk) { |_type, data| receive_event(data) }
          throw self if answer
        end

        def replies
          receive(@body) if @events == false && @replies.empty?
          @replies
        end

        def answer
          replies.find { |reply| !reply.key?('method') && reply['id'] == id }
        end

        def interrupted?
          events? && answer.nil?
        end

        def last_event_id
          @parser.last_event_id unless @parser.last_event_id.empty?
        end

        def retry_after
          @parser.reconnection_time / 1000.0 if @parser.reconnection_time
        end

        private

        def events?
          @events == true
        end

        def receive_event(data)
          receive(data) unless data.empty?
        end

        def receive(data)
          parsed = JSON.parse(data)
          (parsed.is_a?(Array) ? parsed : [parsed]).grep(Hash).each do |reply|
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
