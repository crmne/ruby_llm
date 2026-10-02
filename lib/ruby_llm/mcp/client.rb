# frozen_string_literal: true

module RubyLLM
  class MCP
    # Speaks JSON-RPC to one MCP server over a transport. It speaks the
    # 2026-07-28 revision and falls back to the initialize handshake for
    # servers that predate it, declaring no client capabilities so those
    # servers never call back. A server that rejects 2026-07-28 while
    # listing it gets the request once more; one that answers the handshake
    # with a revision missing from LEGACY_VERSIONS is disconnected.
    #
    # Servers that predate 2026-07-28 may announce that their tools,
    # prompts, or resources changed on the stream of any request. Those
    # notifications reach the block given to ::new once the request is
    # answered, so the block can make requests of its own. #listen opens a
    # subscription for them instead, with subscriptions/listen.
    class Client # :nodoc:
      VERSION = '2026-07-28'
      LEGACY_VERSIONS = %w[2025-11-25 2025-06-18 2025-03-26 2024-11-05].freeze
      UNSUPPORTED_VERSION = -32_022
      MODERN_ERRORS = [-32_020, -32_021, UNSUPPORTED_VERSION].freeze
      METHOD_NOT_FOUND = -32_601
      DISCOVERY_TIMEOUT = 10
      ACKNOWLEDGED = 'notifications/subscriptions/acknowledged'
      CHANGES = %w[
        notifications/tools/list_changed notifications/prompts/list_changed
        notifications/resources/list_changed notifications/resources/updated
      ].freeze

      attr_reader :version

      def initialize(transport, capabilities: {}, &on_change)
        @transport = transport
        @capabilities = capabilities
        @on_change = on_change
        @connecting = Mutex.new
      end

      def server
        @connecting.synchronize { @server ||= discover || handshake }
      end

      def request(method, params = {}, headers: {}, &)
        server
        call(method, params, headers:, &)
      rescue HTTP::SessionExpired
        @connecting.synchronize { @server = handshake }
        call(method, params, headers:, &)
      end

      def list(method, key)
        page = request(method)
        items = page.fetch(key, [])
        while (cursor = page['nextCursor'])
          page = request(method, { cursor: })
          items += page.fetch(key, [])
        end
        items
      end

      # Subscribes to +changes+, a subscriptions/listen filter, and yields
      # each notification of the subscription, starting with the server's
      # acknowledgment. Returns when the server ends the subscription and
      # raises Error when it refuses one or the stream breaks.
      def listen(changes, &)
        server
        raise ConfigurationError, 'The MCP transport does not respond to listen' unless @transport.respond_to?(:listen)
        raise Error.new('The MCP server predates subscriptions/listen', code: METHOD_NOT_FOUND) unless modern?

        subscribe(changes, &)
      end

      def modern?
        version == VERSION
      end

      def close
        @connecting.synchronize do
          @transport.close
          @server = nil
          @version = nil
        end
      end

      private

      def discover
        @version = VERSION
        result = call('server/discover', timeout: DISCOVERY_TIMEOUT)
        result if Array(result['supportedVersions']).include?(VERSION)
      rescue Error => e
        raise if MODERN_ERRORS.include?(e.code)
      end

      def handshake
        @version = nil
        params = { protocolVersion: LEGACY_VERSIONS.first, capabilities: {}, clientInfo: client_info }
        result = call('initialize', params)
        unless LEGACY_VERSIONS.include?(result['protocolVersion'])
          @transport.close
          raise Error, "The server answered with protocol version #{result['protocolVersion']}, " \
                       'which RubyLLM does not speak'
        end

        @version = result['protocolVersion']
        @transport.notify(message('notifications/initialized'), version:)
        result
      end

      def call(method, params = {}, timeout: nil, headers: {}, retried: false, &on_notification)
        request = message(method, params, id: SecureRandom.uuid)
        answer(exchange(request, timeout:, headers:, &on_notification))
      rescue Error => e
        raise if retried || !offers_version?(e)

        call(method, params, timeout:, headers:, retried: true, &on_notification)
      end

      def exchange(request, timeout:, headers:, &on_notification)
        changes = []
        @transport.request(request, version:, timeout:, headers:) do |notification|
          CHANGES.include?(notification['method']) ? changes << notification : on_notification&.call(notification)
        end
      rescue CancelledError
        cancel(request)
        raise
      ensure
        changes.each { |change| @on_change&.call(change) }
      end

      def subscribe(changes)
        request = message('subscriptions/listen', { notifications: changes }, id: SecureRandom.uuid)
        ending = catch(request) do
          @transport.listen(request, version:) do |notification|
            throw request, notification if cancels?(notification, request)
            yield notification
          end
        end
        answer(ending)
      rescue CancelledError
        cancel(request)
        raise
      end

      def cancels?(notification, request)
        notification['method'] == 'notifications/cancelled' && notification.dig('params', 'requestId') == request[:id]
      end

      def cancel(request)
        @transport.cancel(message('notifications/cancelled', { requestId: request[:id] }), version:)
      end

      def answer(response)
        error = response['error']
        raise Error.new(error['message'], code: error['code'], data: error['data']) if error

        response['result']
      end

      def offers_version?(error)
        supported = error.data['supported'] if error.data.is_a?(Hash)
        modern? && error.code == UNSUPPORTED_VERSION && Array(supported).include?(VERSION)
      end

      def message(method, params = {}, id: nil)
        params = params.merge(_meta: meta.merge(params.fetch(:_meta, {}))) if modern?
        { jsonrpc: '2.0', id:, method:, params: }.compact
      end

      def meta
        {
          'io.modelcontextprotocol/protocolVersion' => VERSION,
          'io.modelcontextprotocol/clientInfo' => client_info,
          'io.modelcontextprotocol/clientCapabilities' => @capabilities
        }
      end

      def client_info
        { name: 'ruby_llm', version: RubyLLM::VERSION }
      end
    end
  end
end
