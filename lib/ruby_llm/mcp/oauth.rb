# frozen_string_literal: true

require 'digest'
require 'openssl'
require 'strscan'

module RubyLLM
  class MCP
    # OAuth for one MCP server and one owner, following the 2026-07-28
    # authorization spec: protected resource metadata, authorization server
    # discovery, client ID metadata documents or dynamic registration when no
    # client is configured, PKCE, resource indicators, issuer checks, and
    # token refresh. Credentials live in the configured
    # +mcp_credential_store+, keyed by owner and server.
    #
    # Two grants need no user to authorize: the client credentials grant
    # of the OAuth Client Credentials extension, and the JWT bearer grant
    # (RFC 7523 section 2.1). The latter presents a token the workload's
    # platform issued (Workload Identity Federation) or an identity
    # assertion grant the user's identity provider issued for their ID
    # token (Enterprise-Managed Authorization). As the extensions' flows
    # describe, a token is requested once the server rejects a request
    # without one, and again before it expires. Pre-registered clients
    # authenticate with their secret or with a private_key_jwt assertion
    # (RFC 7523 section 2.2) addressed to the authorization server's
    # issuer.
    #
    # A server that requires DPoP-bound tokens (RFC 9449) gets them: new
    # tokens are bound to a key kept with them in the credentials, and
    # every token request and server request carries a fresh proof with
    # the nonce the server last supplied.
    class OAuth # :nodoc:
      PENDING_FOR = 600
      REFRESH_EARLY = 60
      ASSERTION_FOR = 60
      GRANTS = %i[authorization_code client_credentials jwt_bearer].freeze
      JWT_BEARER = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
      TOKEN_EXCHANGE = 'urn:ietf:params:oauth:grant-type:token-exchange'
      ID_JAG = 'urn:ietf:params:oauth:token-type:id-jag'
      ID_TOKEN = 'urn:ietf:params:oauth:token-type:id_token'
      CLIENT_ASSERTION = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      CLIENT_CREDENTIALS = 'io.modelcontextprotocol/oauth-client-credentials'
      ENTERPRISE_MANAGED = 'io.modelcontextprotocol/enterprise-managed-authorization'
      SERVER_FIELDS = %w[
        issuer token_endpoint token_endpoint_auth_methods_supported token_endpoint_auth_signing_alg_values_supported
        authorization_response_iss_parameter_supported
      ].freeze
      CLIENT_FIELDS = %w[client_id client_secret issuer server redirect_uri dpop_key].freeze
      TOKEN = /[!\#$%&'*+.^_`|~0-9A-Za-z-]+/
      PARAMETER = /#{TOKEN}\s*=/
      QUOTED = /"((?:[^"\\]|\\.)*)"/
      AUTHORIZATION_SERVER_PATHS = [
        '/.well-known/oauth-authorization-server%<path>s',
        '/.well-known/openid-configuration%<path>s',
        '%<path>s/.well-known/openid-configuration'
      ].freeze

      @refreshes = Hash.new { |refreshes, key| refreshes[key] = Mutex.new }
      @refreshes_lock = Mutex.new

      def self.memory_store
        @memory_store ||= MemoryStore.new
      end

      # Returns the authorization extensions that the options of MCP.oauth
      # use, as client capabilities declare them, so servers that require
      # an extension know the client follows it.
      def self.extensions(settings)
        return {} unless settings

        names = []
        names << CLIENT_CREDENTIALS if settings[:grant] == :client_credentials
        names << ENTERPRISE_MANAGED if settings[:identity_provider]
        names.to_h { |name| [name, {}] }
      end

      # Runs the block while no other thread in this process refreshes the
      # credentials stored under +key+.
      def self.refreshing(key, &)
        @refreshes_lock.synchronize { @refreshes[key] }.synchronize(&)
      end

      # Reads the challenges of a WWW-Authenticate header (RFC 9110
      # section 11.6.1) into their parameters, keyed by lowercase scheme.
      def self.challenge(header)
        scanner = StringScanner.new(header.to_s)
        challenges = {}
        while scanner.skip(/[\s,]*/) && (scheme = scanner.scan(TOKEN))
          parameters = challenges[scheme.downcase] ||= {}
          while scanner.skip(/[\s,]*/) && scanner.check(PARAMETER)
            name = scanner.scan(TOKEN).downcase.to_sym
            scanner.skip(/\s*=\s*/)
            value = scanner.scan(QUOTED) ? scanner[1].gsub(/\\(.)/, '\1') : scanner.scan(/[^\s,]*/)
            parameters[name] ||= value
          end
        end
        challenges
      end

      def initialize(server_url, owner:, scopes: nil, client_id: nil, client_secret: nil, grant: nil,
                     private_key: nil, assertion: nil, identity_provider: nil, config: RubyLLM.config,
                     resolve: ->(value) { value })
        @server_url = server_url.to_s
        @owner = owner
        @scopes = scopes
        @client_id = resolve.call(client_id)
        @client_secret = resolve.call(client_secret)
        @private_key = resolve.call(private_key)
        @assertion = assertion
        @identity_provider = identity_provider
        @grant = grant || (assertion || identity_provider ? :jwt_bearer : :authorization_code)
        @resolve = resolve
        @config = config
      end

      def authorized?
        credential&.key?('access_token')
      end

      def access_token
        return unless authorized?

        renew if expiring?
        credential['access_token']
      end

      # Returns the headers that authorize a +verb+ request to the server:
      # none without a token, and a proof of possession with a bound one.
      def authorization_headers(verb = 'POST')
        token = access_token or return {}
        return { 'Authorization' => "Bearer #{token}" } unless credential['token_type'] == 'DPoP'

        proof = proofs.sign(credential['dpop_key'], @server_url, token:, verb:)
        { 'Authorization' => "DPoP #{token}", 'DPoP' => proof }
      end

      # Answers the server's rejection of a request, given its challenge,
      # its DPoP nonce, and the ways the request +recovered+ before. Returns
      # how to send it again, +:nonce+ with the nonce in its proof or
      # +:token+ with a new token, or +nil+ when it is not worth sending
      # again.
      def recover(challenge, nonce: nil, recovered: [])
        @challenge = challenge
        remember_nonce(nonce)
        recovery = nonce && nonce_requested? ? :nonce : :token
        return if recovered.include?(recovery)

        recovery if recovery == :nonce || renewed?
      end

      # Keeps the DPoP nonce the server supplied with a response for the
      # next proof (RFC 9449 section 9).
      def remember_nonce(nonce)
        proofs.remember(@server_url, nonce)
      end

      def refresh
        return false unless credential&.key?('refresh_token')

        used = credential['access_token']
        synchronize do
          @credential = store.read(key)
          next true if credential && credential['access_token'] != used
          next false unless credential&.key?('refresh_token')

          store_tokens(token_request('refresh_token', refresh_token: credential['refresh_token']))
          true
        end
      rescue Error
        false
      end

      def authorization_url(redirect_uri:, challenge: nil)
        raise ConfigurationError, "The #{@grant} grant needs no authorization" unless authorization_code?

        @challenge = challenge
        server = authorization_server
        client = client_for(server, redirect_uri)
        verifier = SecureRandom.urlsafe_base64(64)
        state = SecureRandom.urlsafe_base64(32)
        pending = client.merge('state' => state, 'verifier' => verifier, 'redirect_uri' => redirect_uri,
                               'issuer' => server['issuer'], 'scope' => scopes_for(server),
                               'dpop_key' => binding_key, 'expires_at' => Time.now.to_i + PENDING_FOR)
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
                                                     code_verifier: pending['verifier'], client: pending)
        store_tokens(tokens, client: pending.slice(*CLIENT_FIELDS, 'scope'))
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

      def synchronize(&block)
        self.class.refreshing(key) { store.respond_to?(:synchronize) ? store.synchronize(key, &block) : yield }
      end

      def store_tokens(tokens, client: nil)
        data = credential.to_h.except('pending')
        data = data.except(*CLIENT_FIELDS).merge(client) if client
        data = data.merge('access_token' => tokens['access_token'], 'scope' => tokens['scope'] || data['scope'],
                          'expires_at' => (Time.now.to_i + tokens['expires_in'].to_i if tokens['expires_in']),
                          'token_type' => ('DPoP' if tokens['token_type'].to_s.casecmp?('DPoP')))
        data['refresh_token'] = tokens['refresh_token'] if tokens['refresh_token']
        write(data.compact)
      end

      def expiring?
        credential['expires_at'] && credential['expires_at'] - REFRESH_EARLY < Time.now.to_i
      end

      def authorization_code?
        @grant == :authorization_code
      end

      def renew
        authorization_code? ? refresh : obtain
      end

      def renewed?
        authorization_code? ? authorized? && refresh : obtain
      end

      # Requests a token with the configured grant, unless another worker
      # has replaced the one the server rejected. Failures raise
      # UnauthorizedError: Client falls back to the older handshake on an
      # MCP::Error, which would ask the authorization server again.
      def obtain
        rejected = credential&.fetch('access_token', nil)
        synchronize do
          @credential = store.read(key)
          next true if authorized? && credential['access_token'] != rejected && !expiring?

          server = authorization_server
          client = granting_client(server)
          scope = scopes_for(server)
          grant_type, grant = grant_parameters(server, scope)
          store_tokens(token_request(grant_type, client:, scope:, **grant), client:)
          true
        end
      rescue Error => e
        raise UnauthorizedError.new(e.message, response: e.response)
      end

      def granting_client(server)
        if @grant == :client_credentials && @client_id.nil?
          raise ConfigurationError, 'The client_credentials grant needs a client_id'
        end

        preregistered_client(server).merge('issuer' => server['issuer'], 'server' => server.slice(*SERVER_FIELDS),
                                           'dpop_key' => binding_key).compact
      end

      # RFC 9449 section 7.1 and RFC 9728 section 2: a server requires
      # DPoP-bound tokens when it challenges with the DPoP scheme and not
      # Bearer, or when its metadata says so.
      def dpop_required?
        schemes = @challenge.to_h.keys
        @dpop_required || (schemes.include?('dpop') && !schemes.include?('bearer'))
      end

      def binding_key
        Key.generate.to_pem if dpop_required?
      end

      # RFC 9449 section 9: a server that wants a nonce in proofs answers
      # with use_dpop_nonce and the nonce to use.
      def nonce_requested?
        @challenge.to_h.dig('dpop', :error) == 'use_dpop_nonce' && credential&.fetch('token_type', nil) == 'DPoP'
      end

      def proofs
        @proofs ||= Proofs.new
      end

      # Assertions are resolved for every token, since workload platforms
      # rotate the tokens they issue and ID tokens expire.
      def grant_parameters(server, scope)
        return ['client_credentials', {}] if @grant == :client_credentials

        assertion = @identity_provider ? identity_assertion(server, scope) : @resolve.call(@assertion)
        raise ConfigurationError, 'The jwt_bearer grant needs an assertion or an identity provider' unless assertion

        [JWT_BEARER, { assertion: }]
      end

      # Exchanges the user's ID token at the identity provider for an
      # Identity Assertion JWT Authorization Grant addressed to the
      # server's authorization server (enterprise-managed authorization,
      # section 4). Only that grant is forwarded: any other token the
      # identity provider returns is the user's credential there.
      def identity_assertion(server, scope)
        provider = Hash(@resolve.call(@identity_provider)).to_h { |name, value| [name.to_sym, @resolve.call(value)] }
        unless provider[:issuer] && provider[:id_token]
          raise ConfigurationError, 'The identity provider needs an issuer and an id_token'
        end

        client = { 'client_id' => provider[:client_id], 'client_secret' => provider[:client_secret],
                   'server' => discover_authorization_server(provider[:issuer]) }
        grant = token_request(TOKEN_EXCHANGE, client:, key: nil, requested_token_type: ID_JAG,
                                              audience: server['issuer'], scope:, subject_token: provider[:id_token],
                                              subject_token_type: ID_TOKEN)
        return grant['access_token'] if grant['issued_token_type'] == ID_JAG

        raise Error, "#{provider[:issuer]} did not issue an identity assertion grant"
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

      def token_request(grant_type, client: credential, key: (signing_key if client['client_id'] == @client_id),
                        **params)
        server = client['server'] or raise Error, 'No authorization server known; authorize first'
        send_token_request(server, client, key, params.merge(grant_type:))
      rescue Error => e
        forget_registration(client) if oauth_error(e) == 'invalid_client'
        raise
      end

      # RFC 9449 section 8: an authorization server that wants a nonce in
      # the proof answers use_dpop_nonce once with the nonce to use. Every
      # attempt signs a new proof and a new client assertion.
      def send_token_request(server, client, key, params, retried: false)
        url = server['token_endpoint']
        form = params.merge(client_id: client['client_id'], resource:)
        headers = { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'application/json' }
        authenticate(client, server, form, headers, key)
        headers['DPoP'] = proofs.sign(client['dpop_key'], url) if client['dpop_key']
        post(url, URI.encode_www_form(form.compact), headers)
      rescue Error => e
        raise if retried || !client['dpop_key'] || oauth_error(e) != 'use_dpop_nonce'

        send_token_request(server, client, key, params, retried: true)
      end

      def oauth_error(error)
        error.data['error'] if error.data.is_a?(Hash)
      end

      def forget_registration(client)
        registration = registration_key(client['issuer'], client['redirect_uri'])
        store.delete(registration) if store.read(registration)&.fetch('client_id', nil) == client['client_id']
      end

      def authenticate(client, server, form, headers, key)
        if key
          form.delete(:client_id)
          form.merge!(client_assertion_type: CLIENT_ASSERTION,
                      client_assertion: client_assertion(key, client['client_id'], server))
        elsif client['client_secret']
          methods = server['token_endpoint_auth_methods_supported'] || ['client_secret_basic']
          if methods.include?('client_secret_basic')
            headers['Authorization'] = "Basic #{basic_credentials(client['client_id'], client['client_secret'])}"
          else
            form[:client_secret] = client['client_secret']
          end
        end
      end

      # RFC 6749 section 2.3.1: the client ID and secret are form-encoded
      # before they become the user and password of Basic authentication.
      def basic_credentials(client_id, client_secret)
        Base64.strict_encode64([client_id, client_secret].map { |part| URI.encode_www_form_component(part) }.join(':'))
      end

      # RFC 7523bis section 4: the issuer is the sole audience, so no other
      # authorization server can replay the assertion, and the explicit
      # type tells servers the client follows that rule.
      def client_assertion(key, client_id, server)
        now = Time.now.to_i
        claims = { iss: client_id, sub: client_id, aud: server['issuer'], iat: now, exp: now + ASSERTION_FOR,
                   jti: SecureRandom.uuid }
        algorithm = key.algorithm(server['token_endpoint_auth_signing_alg_values_supported'])
        key.jwt(claims, algorithm:, typ: 'client-authentication+jwt')
      end

      def signing_key
        @signing_key ||= (Key.new(@private_key) if @private_key)
      end

      def authorization_server
        metadata = protected_resource_metadata
        server = metadata ? described_authorization_server(metadata) : legacy_authorization_server
        if authorization_code? && !Array(server['code_challenge_methods_supported']).include?('S256')
          raise Error, "#{server['issuer']} does not support PKCE with S256"
        end

        server
      end

      def described_authorization_server(metadata)
        issuer = Array(metadata['authorization_servers']).first
        raise Error, "#{@server_url} names no authorization server" unless issuer

        @resource = checked_resource(metadata['resource'])
        @scopes_supported = metadata['scopes_supported']
        @dpop_required = metadata['dpop_bound_access_tokens_required'] == true
        discover_authorization_server(issuer)
      end

      def protected_resource_metadata
        url = challenged(:resource_metadata)
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
        server = authorization_server_metadata(issuer)
        return server if same_issuer?(server['issuer'], issuer)

        named = server['issuer']
        raise Error, "#{issuer} metadata names a different issuer" unless named.is_a?(String) && URI(named).host

        server = authorization_server_metadata(named)
        raise Error, "#{issuer} metadata names a different issuer" unless same_issuer?(server['issuer'], named)

        server
      rescue URI::InvalidURIError
        raise Error, "#{issuer} metadata names a different issuer"
      end

      def authorization_server_metadata(issuer)
        uri = URI(issuer)
        path = uri.path.chomp('/')
        urls = AUTHORIZATION_SERVER_PATHS.map { |pattern| URI.join(uri, format(pattern, path:)).to_s }
        urls = urls.first(2) if path.empty?
        first_json(urls.uniq) or raise Error, "#{issuer} publishes no authorization server metadata"
      end

      # RFC 3986 section 6.2.3: an empty path and "/" name the same resource.
      def same_issuer?(one, other)
        [one, other].map { |issuer| issuer.to_s.sub(%r{\A([a-z][a-z0-9+.-]*://[^/?#]+)/(?=[?#]|\z)}i, '\\1') }.uniq.one?
      end

      def client_for(server, redirect_uri)
        return preregistered_client(server) if @client_id

        metadata_client_id = @config.mcp_client_id
        if metadata_client_id && server['client_id_metadata_document_supported']
          return { 'client_id' => metadata_client_id }
        end

        register(server, redirect_uri)
      end

      def preregistered_client(server)
        issuer_key = "issuer:#{@client_id} #{@server_url}"
        issuer = store.read(issuer_key)&.fetch('issuer', nil)
        store.write(issuer_key, { 'issuer' => server['issuer'] }, owner: nil) unless issuer
        if issuer && !same_issuer?(issuer, server['issuer'])
          raise Error, "#{@client_id || 'The workload'} is registered with #{issuer}, " \
                       "but #{@server_url} now uses #{server['issuer']}"
        end

        { 'client_id' => @client_id, 'client_secret' => @client_secret }.compact
      end

      def register(server, redirect_uri)
        endpoint = server['registration_endpoint'] or raise Error, "#{server['issuer']} does not register clients"
        registration = registration_key(server['issuer'], redirect_uri)
        scope = scopes_for(server)
        registered = store.read(registration)
        if registered && registered_for?(registered['scope'], scope)
          return registered.slice('client_id', 'client_secret')
        end

        body = JSON.generate({
          client_name: @config.mcp_client_name, redirect_uris: [redirect_uri], response_types: ['code'],
          grant_types: %w[authorization_code refresh_token], token_endpoint_auth_method: 'none',
          application_type: HTTP.loopback?(redirect_uri) ? 'native' : 'web', scope:
        }.compact)
        client = post(endpoint, body, 'Content-Type' => 'application/json').slice('client_id', 'client_secret')
        store.write(registration, client.merge('scope' => scope).compact, owner: nil)
        client
      end

      def registered_for?(registered, requested)
        (requested.to_s.split - registered.to_s.split).empty?
      end

      def registration_key(issuer, redirect_uri)
        "client:#{issuer} #{redirect_uri}"
      end

      def scopes_for(server)
        requested = challenged(:scope)&.split
        scopes = if requested then Array(@scopes) + requested + credential.to_h['scope'].to_s.split
                 else Array(@scopes || @scopes_supported)
                 end
        scopes += ['offline_access'] if offline_access?(server)
        scopes.uniq.join(' ') unless scopes.empty?
      end

      def offline_access?(server)
        authorization_code? && Array(server['scopes_supported']).include?('offline_access')
      end

      def challenged(name)
        @challenge.to_h.each_value.filter_map { |parameters| parameters[name] }.first
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
        response = connection(url).post(url, body, headers)
        proofs.remember(url, response.headers['dpop-nonce'])
        parse(response)
      rescue Faraday::Error => e
        raise refusal(url, e.response && Faraday::Response.new(status: e.response[:status], body: e.response[:body],
                                                               response_headers: e.response[:headers]))
      end

      def refusal(url, response)
        proofs.remember(url, Hash(response&.headers)['dpop-nonce'])
        details = begin
          JSON.parse(response&.body.to_s)
        rescue JSON::ParserError
          {}
        end
        details = {} unless details.is_a?(Hash)
        Error.new("#{URI(url).host} refused the request: #{details['error_description'] || details['error']}",
                  data: details, response:)
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
