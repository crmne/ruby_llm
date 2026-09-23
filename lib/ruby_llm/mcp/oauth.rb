# frozen_string_literal: true

require 'digest'
require 'openssl'

module RubyLLM
  class MCP
    # OAuth for one MCP server and one owner, following the 2026-07-28
    # authorization spec: protected resource metadata, authorization server
    # discovery, client ID metadata documents or dynamic registration when no
    # client is configured, PKCE, resource indicators, issuer checks, and
    # token refresh. Credentials live in the configured
    # +mcp_credential_store+, keyed by owner and server.
    class OAuth # :nodoc:
      PENDING_FOR = 600
      REFRESH_EARLY = 60
      SERVER_FIELDS = %w[
        issuer token_endpoint token_endpoint_auth_methods_supported authorization_response_iss_parameter_supported
      ].freeze
      AUTHORIZATION_SERVER_PATHS = [
        '/.well-known/oauth-authorization-server%<path>s',
        '/.well-known/openid-configuration%<path>s',
        '%<path>s/.well-known/openid-configuration'
      ].freeze

      def self.memory_store
        @memory_store ||= MemoryStore.new
      end

      # Reads the parameters of a Bearer WWW-Authenticate challenge.
      def self.challenge(header)
        header.to_s.scan(/(\w+)="([^"]*)"/).to_h { |name, value| [name.to_sym, value] }
      end

      def initialize(server_url, owner:, scopes:, client_id:, client_secret:, config: RubyLLM.config)
        @server_url = server_url.to_s
        @owner = owner
        @scopes = scopes
        @client_id = client_id
        @client_secret = client_secret
        @config = config
      end

      def authorized?
        credential&.key?('access_token')
      end

      def access_token
        return unless authorized?

        refresh if expiring?
        credential['access_token']
      end

      def refresh
        return false unless credential&.key?('refresh_token')

        store_tokens(token_request('refresh_token', refresh_token: credential['refresh_token']))
        true
      rescue Error
        false
      end

      def authorization_url(redirect_uri:, challenge: nil)
        @challenge = challenge
        server = authorization_server
        client = client_for(server, redirect_uri)
        verifier = SecureRandom.urlsafe_base64(64)
        state = SecureRandom.urlsafe_base64(32)
        pending = client.merge('state' => state, 'verifier' => verifier, 'redirect_uri' => redirect_uri,
                               'issuer' => server['issuer'], 'expires_at' => Time.now.to_i + PENDING_FOR)
        write(credential.to_h.merge('pending' => pending, 'server' => server.slice(*SERVER_FIELDS)))

        query = { response_type: 'code', client_id: client['client_id'], redirect_uri:, state:,
                  code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
                  code_challenge_method: 'S256', resource:, scope: scopes_for(server) }.compact
        "#{server['authorization_endpoint']}?#{URI.encode_www_form(query)}"
      end

      def authorize(params)
        pending = credential&.fetch('pending', nil) or raise Error, 'No authorization in progress'
        check_callback(pending, params)
        tokens = token_request('authorization_code', code: value(params, :code), redirect_uri: pending['redirect_uri'],
                                                     code_verifier: pending['verifier'], pending:)
        store_tokens(tokens, client: pending.slice('client_id', 'client_secret', 'issuer'))
      end

      def deauthorize
        @credential = nil
        store.delete(key)
      end

      private

      def credential
        @credential ||= store.read(key)
      end

      def write(data)
        @credential = data
        store.write(key, data, owner: @owner)
      end

      def store_tokens(tokens, client: nil)
        data = credential.to_h.except('pending').merge(client.to_h)
        data = data.merge('access_token' => tokens['access_token'], 'scope' => tokens['scope'] || data['scope'],
                          'expires_at' => (Time.now.to_i + tokens['expires_in'].to_i if tokens['expires_in']))
        data['refresh_token'] = tokens['refresh_token'] if tokens['refresh_token']
        write(data.compact)
      end

      def expiring?
        credential['expires_at'] && credential['expires_at'] - REFRESH_EARLY < Time.now.to_i
      end

      def check_callback(pending, params)
        raise Error, 'The authorization expired; start again' if pending['expires_at'] < Time.now.to_i

        check_issuer(pending, value(params, :iss))
        check_state(pending, value(params, :state).to_s)
        error = value(params, :error)
        raise Error, "Authorization failed: #{value(params, :error_description) || error}" if error
      end

      def check_issuer(pending, issuer)
        raise Error, 'The authorization response came from the wrong issuer' if issuer && issuer != pending['issuer']
        raise Error, 'The authorization server did not identify itself' if issuer.nil? && issuer_required?
      end

      def check_state(pending, state)
        expected = pending['state']
        return if state.bytesize == expected.bytesize && OpenSSL.fixed_length_secure_compare(state, expected)

        raise Error, 'The authorization state does not match'
      end

      def issuer_required?
        credential.dig('server', 'authorization_response_iss_parameter_supported') == true
      end

      def token_request(grant_type, pending: nil, **params)
        client = pending || credential
        server = credential['server'] or raise Error, 'No authorization server known; authorize first'
        form = params.merge(grant_type:, client_id: client['client_id'], resource:)
        headers = { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'application/json' }
        authenticate(client, server, form, headers) if client['client_secret']
        post(server['token_endpoint'], URI.encode_www_form(form.compact), headers)
      end

      def authenticate(client, server, form, headers)
        methods = server['token_endpoint_auth_methods_supported'] || ['client_secret_basic']
        if methods.include?('client_secret_basic')
          credentials = Base64.strict_encode64("#{client['client_id']}:#{client['client_secret']}")
          headers['Authorization'] = "Basic #{credentials}"
        else
          form[:client_secret] = client['client_secret']
        end
      end

      def authorization_server
        metadata = protected_resource_metadata
        issuer = Array(metadata['authorization_servers']).first
        raise Error, "#{@server_url} names no authorization server" unless issuer

        @resource = checked_resource(metadata['resource'])
        @scopes_supported = metadata['scopes_supported']
        server = discover_authorization_server(issuer)
        unless Array(server['code_challenge_methods_supported']).include?('S256')
          raise Error, "#{issuer} does not support PKCE with S256"
        end

        server
      end

      def protected_resource_metadata
        url = @challenge&.dig(:resource_metadata)
        return get_json(url) if url

        uri = URI(@server_url)
        path = uri.path.chomp('/')
        candidates = ["/.well-known/oauth-protected-resource#{path}", '/.well-known/oauth-protected-resource'].uniq
        first_json(candidates.map { |candidate| URI.join(uri, candidate).to_s }) ||
          raise(Error, "#{@server_url} publishes no protected resource metadata")
      end

      def checked_resource(resource)
        return unless resource
        return resource if @server_url.chomp('/').start_with?(resource.chomp('/'))

        raise Error, "#{@server_url} published metadata for another resource: #{resource}"
      end

      def discover_authorization_server(issuer)
        uri = URI(issuer)
        path = uri.path.chomp('/')
        urls = AUTHORIZATION_SERVER_PATHS.map { |pattern| URI.join(uri, format(pattern, path:)).to_s }
        urls = urls.first(2) if path.empty?
        server = first_json(urls.uniq) or raise Error, "#{issuer} publishes no authorization server metadata"
        raise Error, "#{issuer} metadata names a different issuer" unless server['issuer'] == issuer

        server
      end

      def client_for(server, redirect_uri)
        return { 'client_id' => @client_id, 'client_secret' => @client_secret }.compact if @client_id

        metadata_client_id = @config.mcp_client_id
        if metadata_client_id && server['client_id_metadata_document_supported']
          return { 'client_id' => metadata_client_id }
        end

        register(server, redirect_uri)
      end

      def register(server, redirect_uri)
        endpoint = server['registration_endpoint'] or raise Error, "#{server['issuer']} does not register clients"
        registration_key = "client:#{server['issuer']} #{redirect_uri}"
        registered = store.read(registration_key)
        return registered if registered

        body = JSON.generate(
          client_name: @config.mcp_client_name, redirect_uris: [redirect_uri], response_types: ['code'],
          grant_types: %w[authorization_code refresh_token], token_endpoint_auth_method: 'none',
          application_type: HTTP.loopback?(redirect_uri) ? 'native' : 'web'
        )
        client = post(endpoint, body, 'Content-Type' => 'application/json').slice('client_id', 'client_secret')
        store.write(registration_key, client, owner: nil)
        client
      end

      def scopes_for(server)
        scopes = @scopes || @challenge&.dig(:scope)&.split || @scopes_supported
        scopes = Array(scopes)
        scopes += ['offline_access'] if Array(server['scopes_supported']).include?('offline_access')
        scopes.uniq.join(' ') unless scopes.empty?
      end

      def resource
        @resource || @server_url.chomp('/')
      end

      def first_json(urls)
        urls.each do |url|
          return get_json(url)
        rescue Faraday::Error, Error
          next
        end
        nil
      end

      def get_json(url)
        parse(connection(url).get(url, nil, 'Accept' => 'application/json'))
      end

      def post(url, body, headers)
        parse(connection(url).post(url, body, headers))
      rescue Faraday::Error => e
        details = begin
          JSON.parse(e.response&.dig(:body).to_s)
        rescue JSON::ParserError
          {}
        end
        raise Error, "#{URI(url).host} refused the request: #{details['error_description'] || details['error']}"
      end

      def parse(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, 'The authorization server did not answer with JSON'
      end

      def connection(url)
        raise Error, "OAuth endpoints must use HTTPS: #{url}" unless HTTP.secure?(url)

        Transport::Connection.basic(@config)
      end

      def value(params, name)
        params[name] || params[name.to_s]
      end

      def store
        @config.mcp_credential_store || self.class.memory_store
      end

      def key
        owner = @owner.respond_to?(:to_gid) ? @owner.to_gid.to_s : @owner.to_s
        "#{owner}@#{@server_url}"
      end
    end
  end
end
