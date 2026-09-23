# frozen_string_literal: true

module RubyLLM
  class MCP
    # Speaks JSON-RPC to one MCP server over a transport. It speaks the
    # 2026-07-28 revision and falls back to the initialize handshake for
    # servers that predate it, declaring no client capabilities so those
    # servers never call back.
    class Client # :nodoc:
      VERSION = '2026-07-28'
      LEGACY_VERSION = '2025-11-25'
      MODERN_ERRORS = [-32_020, -32_021, -32_022].freeze
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

      def request(method, params = {}, &)
        server
        call(method, params, &)
      end

      def list(method, key)
        page = request(method)
        items = page.fetch(key, [])
        while (cursor = page['nextCursor'])
          page = request(method, cursor:)
          items += page.fetch(key, [])
        end
        items
      end

      def modern?
        version == VERSION
      end

      def close
        @transport.close
      end

      private

      def discover
        @version = VERSION
        call('server/discover', timeout: DISCOVERY_TIMEOUT)
      rescue Error => e
        raise if MODERN_ERRORS.include?(e.code)
      end

      def handshake
        @version = nil
        result = call('initialize', { protocolVersion: LEGACY_VERSION, capabilities: {}, clientInfo: client_info })
        @version = result['protocolVersion']
        @transport.notify(message('notifications/initialized'), version:)
        result
      end

      def call(method, params = {}, timeout: nil, &)
        request = message(method, params, id: SecureRandom.uuid)
        response = begin
          @transport.request(request, version:, timeout:, &)
        rescue CancelledError
          @transport.cancel(message('notifications/cancelled', { requestId: request[:id] }), version:)
          raise
        end
        error = response['error']
        raise Error.new(error['message'], code: error['code'], data: error['data']) if error

        response['result']
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
