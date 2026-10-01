# frozen_string_literal: true

module RubyLLM
  class MCP
    # Speaks JSON-RPC to one MCP server over a transport. It speaks the
    # 2026-07-28 revision and falls back to the initialize handshake for
    # servers that predate it, declaring no client capabilities so those
    # servers never call back. A server that rejects 2026-07-28 while
    # listing it gets the request once more; one that answers the handshake
    # with a revision missing from LEGACY_VERSIONS is disconnected.
    class Client # :nodoc:
      VERSION = '2026-07-28'
      LEGACY_VERSIONS = %w[2025-11-25 2025-06-18 2025-03-26 2024-11-05].freeze
      UNSUPPORTED_VERSION = -32_022
      MODERN_ERRORS = [-32_020, -32_021, UNSUPPORTED_VERSION].freeze
      DISCOVERY_TIMEOUT = 10

      attr_reader :version

      def initialize(transport, capabilities: {})
        @transport = transport
        @capabilities = capabilities
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

      def call(method, params = {}, timeout: nil, headers: {}, retried: false, &)
        request = message(method, params, id: SecureRandom.uuid)
        response = begin
          @transport.request(request, version:, timeout:, headers:, &)
        rescue CancelledError
          @transport.cancel(message('notifications/cancelled', { requestId: request[:id] }), version:)
          raise
        end
        error = response['error']
        raise Error.new(error['message'], code: error['code'], data: error['data']) if error

        response['result']
      rescue Error => e
        raise if retried || !offers_version?(e)

        call(method, params, timeout:, headers:, retried: true, &)
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
