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
        header.to_s.sub(/\A\s*Bearer\s+/i, '').split(',').to_h do |pair|
          name, value = pair.split('=', 2).map(&:strip)
          [name.to_sym, value.to_s.delete_prefix('"').delete_suffix('"')]
        end
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
                               'issuer' => server['issuer'], 'scope' => scopes_for(server),
                               'expires_at' => Time.now.to_i + PENDING_FOR)
        write(credential.to_h.merge('pending' => pending.merge('server' => server.slice(*SERVER_FIELDS))))

        query = { response_type: 'code', client_id: client['client_id'], redirect_uri:, state:,
                  code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
                  code_challenge_method: 'S256', resource:, scope: pending['scope'] }.compact
        "#{endpoint(server['authorization_endpoint'])}?#{URI.encode_www_form(query)}"
      end

      def authorize(params)
        pending = credential&.fetch('pending', nil) or raise Error, 'No authorization in progress'
        check_callback(pending, params)
        tokens = token_request('authorization_code', code: value(params, :code), redirect_uri: pending['redirect_uri'],
                                                     code_verifier: pending['verifier'], pending:)
        store_tokens(tokens, client: pending.slice('client_id', 'client_secret', 'issuer', 'server', 'scope'))
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
        credential.dig('pending', 'server', 'authorization_response_iss_parameter_supported') == true
      end

      def token_request(grant_type, pending: nil, **params)
        client = pending || credential
        server = client['server'] or raise Error, 'No authorization server known; authorize first'
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
        server = metadata ? described_authorization_server(metadata) : legacy_authorization_server
        unless Array(server['code_challenge_methods_supported']).include?('S256')
          raise Error, "#{server['issuer']} does not support PKCE with S256"
        end

        server
      end

      def described_authorization_server(metadata)
        issuer = Array(metadata['authorization_servers']).first
        raise Error, "#{@server_url} names no authorization server" unless issuer

        @resource = checked_resource(metadata['resource'])
        @scopes_supported = metadata['scopes_supported']
        discover_authorization_server(issuer)
      end

      def protected_resource_metadata
        url = @challenge&.dig(:resource_metadata)
        return get_json(url) if url && same_origin?(URI(url), URI(@server_url))

        uri = URI(@server_url)
        path = uri.path.chomp('/')
        candidates = ["/.well-known/oauth-protected-resource#{path}", '/.well-known/oauth-protected-resource'].uniq
        first_json(candidates.map { |candidate| URI.join(uri, candidate).to_s })
      end

      # Servers from the 2025-03-26 revision publish no protected resource
      # metadata: their own origin is the authorization server, with default
      # endpoints when it publishes no metadata either.
      def legacy_authorization_server
        origin = URI.join(@server_url, '/').to_s.chomp('/')
        first_json(["#{origin}/.well-known/oauth-authorization-server"]) || {
          'issuer' => origin, 'authorization_endpoint' => "#{origin}/authorize",
          'token_endpoint' => "#{origin}/token", 'registration_endpoint' => "#{origin}/register",
          'code_challenge_methods_supported' => ['S256']
        }
      end

      def checked_resource(resource)
        return unless resource
        return resource if covers?(URI(resource), URI(@server_url))

        raise Error, "#{@server_url} published metadata for another resource: #{resource}"
      end

      def same_origin?(url, server)
        [url.scheme, url.host, url.port] == [server.scheme, server.host, server.port]
      end

      def covers?(resource, server)
        return false if resource.userinfo || server.userinfo
        return false unless same_origin?(resource, server)

        path = resource.path.chomp('/')
        server.path == path || server.path.start_with?("#{path}/")
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
        challenged = @challenge&.dig(:scope)&.split
        scopes = if challenged then Array(@scopes) + challenged + credential.to_h['scope'].to_s.split
                 else Array(@scopes || @scopes_supported)
                 end
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
        endpoint(url)
        Transport::Connection.basic(@config) { |faraday| faraday.adapter(@config.faraday_adapter) }
      end

      def endpoint(url)
        uri = URI(url.to_s)
        loopback_allowed = HTTP.loopback?(@server_url)
        return url if uri.scheme == 'https' && uri.userinfo.nil?
        return url if loopback_allowed && HTTP.secure?(uri)

        raise Error, "OAuth endpoints must use HTTPS: #{url}"
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
