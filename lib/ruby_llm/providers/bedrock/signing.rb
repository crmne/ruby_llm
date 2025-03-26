# frozen_string_literal: true

require 'openssl'
require 'tempfile'
require 'time'
require 'uri'
require 'set'
require 'cgi'
require 'pathname'

module RubyLLM
  module Providers
    module Bedrock
      module Signing
        # Utility class for creating AWS signature version 4 signature. This class
        # provides two methods for generating signatures:
        #
        # * {#sign_request} - Computes a signature of the given request, returning
        #   the hash of headers that should be applied to the request.
        #
        # * {#presign_url} - Computes a presigned request with an expiration.
        #   By default, the body of this request is not signed and the request
        #   expires in 15 minutes.
        #
        # ## Configuration
        #
        # To use the signer, you need to specify the service, region, and credentials.
        # The service name is normally the endpoint prefix to an AWS service. For
        # example:
        #
        #     ec2.us-west-1.amazonaws.com => ec2
        #
        # The region is normally the second portion of the endpoint, following
        # the service name.
        #
        #     ec2.us-west-1.amazonaws.com => us-west-1
        #
        # It is important to have the correct service and region name, or the
        # signature will be invalid.
        #
        # ## Credentials
        #
        # The signer requires credentials. You can configure the signer
        # with static credentials:
        #
        #     signer = Aws::Sigv4::Signer.new(
        #       service: 's3',
        #       region: 'us-east-1',
        #       # static credentials
        #       access_key_id: 'akid',
        #       secret_access_key: 'secret'
        #     )
        #
        # You can also provide refreshing credentials via the `:credentials_provider`.
        # If you are using the AWS SDK for Ruby, you can use any of the credential
        # classes:
        #
        #     signer = Aws::Sigv4::Signer.new(
        #       service: 's3',
        #       region: 'us-east-1',
        #       credentials_provider: Aws::InstanceProfileCredentials.new
        #     )
        #
        # Other AWS SDK for Ruby classes that can be provided via `:credentials_provider`:
        #
        # * `Aws::Credentials`
        # * `Aws::SharedCredentials`
        # * `Aws::InstanceProfileCredentials`
        # * `Aws::AssumeRoleCredentials`
        # * `Aws::ECSCredentials`
        #
        # A credential provider is any object that responds to `#credentials`
        # returning another object that responds to `#access_key_id`, `#secret_access_key`,
        # and `#session_token`.
        module Errors
          # Error raised when AWS credentials are missing or incomplete
          class MissingCredentialsError < ArgumentError
            def initialize(msg = nil)
              super(msg || <<~MSG.strip)
                missing credentials, provide credentials with one of the following options:
                  - :access_key_id and :secret_access_key
                  - :credentials
                  - :credentials_provider
              MSG
            end
          end

          # Error raised when AWS region is not specified
          class MissingRegionError < ArgumentError
            def initialize(*_args)
              super('missing required option :region')
            end
          end
        end

        # Represents a signature for AWS request signing
        class Signature
          # @api private
          def initialize(options)
            options.each_pair do |attr_name, attr_value|
              send("#{attr_name}=", attr_value)
            end
          end

          # @return [Hash<String,String>] A hash of headers that should
          #   be applied to the HTTP request. Header keys are lower
          #   cased strings and may include the following:
          #
          #   * 'host'
          #   * 'x-amz-date'
          #   * 'x-amz-security-token'
          #   * 'x-amz-content-sha256'
          #   * 'authorization'
          #
          attr_accessor :headers

          # @return [String] For debugging purposes.
          attr_accessor :canonical_request

          # @return [String] For debugging purposes.
          attr_accessor :string_to_sign

          # @return [String] For debugging purposes.
          attr_accessor :content_sha256

          # @return [String] For debugging purposes.
          attr_accessor :signature

          # @return [Hash] Internal data for debugging purposes.
          attr_accessor :extra
        end

        # Manages AWS credentials for authentication
        class Credentials
          # @option options [required, String] :access_key_id
          # @option options [required, String] :secret_access_key
          # @option options [String, nil] :session_token (nil)
          def initialize(options = {})
            if options[:access_key_id] && options[:secret_access_key]
              @access_key_id = options[:access_key_id]
              @secret_access_key = options[:secret_access_key]
              @session_token = options[:session_token]
            else
              msg = 'expected both :access_key_id and :secret_access_key options'
              raise ArgumentError, msg
            end
          end

          # @return [String]
          attr_reader :access_key_id

          # @return [String]
          attr_reader :secret_access_key

          # @return [String, nil]
          attr_reader :session_token

          # @return [Boolean] Returns `true` if the access key id and secret
          #   access key are both set.
          def set?
            !access_key_id.nil? &&
              !access_key_id.empty? &&
              !secret_access_key.nil? &&
              !secret_access_key.empty?
          end
        end

        # Users that wish to configure static credentials can use the
        # `:access_key_id` and `:secret_access_key` constructor options.
        # @api private
        class StaticCredentialsProvider
          # @option options [Credentials] :credentials
          # @option options [String] :access_key_id
          # @option options [String] :secret_access_key
          # @option options [String] :session_token (nil)
          def initialize(options = {})
            @credentials = options[:credentials] || Credentials.new(options)
          end

          # @return [Credentials]
          attr_reader :credentials

          # @return [Boolean]
          def set?
            !!credentials && credentials.set?
          end
        end

        ParamComponent = Struct.new(:name, :value, :offset)

        # Handles AWS request signing using SigV4 or SigV4a
        class Signer
          # @overload initialize(service:, region:, access_key_id:, secret_access_key:, session_token:nil, **options)
          #   @param [String] :service The service signing name, e.g. 's3'.
          #   @param [String] :region The region name, e.g. 'us-east-1'. When signing
          #    with sigv4a, this should be a comma separated list of regions.
          #   @param [String] :access_key_id
          #   @param [String] :secret_access_key
          #   @param [String] :session_token (nil)
          #
          # @overload initialize(service:, region:, credentials:, **options)
          #   @param [String] :service The service signing name, e.g. 's3'.
          #   @param [String] :region The region name, e.g. 'us-east-1'. When signing
          #    with sigv4a, this should be a comma separated list of regions.
          #   @param [Credentials] :credentials Any object that responds to the following
          #     methods:
          #
          #     * `#access_key_id` => String
          #     * `#secret_access_key` => String
          #     * `#session_token` => String, nil
          #     * `#set?` => Boolean
          #
          # @overload initialize(service:, region:, credentials_provider:, **options)
          #   @param [String] :service The service signing name, e.g. 's3'.
          #   @param [String] :region The region name, e.g. 'us-east-1'. When signing
          #    with sigv4a, this should be a comma separated list of regions.
          #   @param [#credentials] :credentials_provider An object that responds
          #     to `#credentials`, returning an object that responds to the following
          #     methods:
          #
          #     * `#access_key_id` => String
          #     * `#secret_access_key` => String
          #     * `#session_token` => String, nil
          #     * `#set?` => Boolean
          #
          # @option options [Array<String>] :unsigned_headers ([]) A list of
          #   headers that should not be signed. This is useful when a proxy
          #   modifies headers, such as 'User-Agent', invalidating a signature.
          #
          # @option options [Boolean] :uri_escape_path (true) When `true`,
          #   the request URI path is uri-escaped as part of computing the canonical
          #   request string. This is required for every service, except Amazon S3,
          #   as of late 2016.
          #
          # @option options [Boolean] :apply_checksum_header (true) When `true`,
          #   the computed content checksum is returned in the hash of signature
          #   headers. This is required for AWS Glacier, and optional for
          #   every other AWS service as of late 2016.
          #
          # @option options [Symbol] :signing_algorithm (:sigv4) The
          #   algorithm to use for signing.
          #
          # @option options [Boolean] :omit_session_token (false)
          #   (Supported only when `aws-crt` is available) If `true`,
          #   then security token is added to the final signing result,
          #   but is treated as "unsigned" and does not contribute
          #   to the authorization signature.
          #
          # @option options [Boolean] :normalize_path (true) When `true`, the
          #   uri paths will be normalized when building the canonical request.
          def initialize(options = {})
            @service = extract_service(options)
            @region = extract_region(options)
            @credentials_provider = extract_credentials_provider(options)
            @unsigned_headers = initialize_unsigned_headers(options)
            @uri_escape_path = options.fetch(:uri_escape_path, true)
            @apply_checksum_header = options.fetch(:apply_checksum_header, true)
            @signing_algorithm = options.fetch(:signing_algorithm, :sigv4)
            @normalize_path = options.fetch(:normalize_path, true)
            @omit_session_token = options.fetch(:omit_session_token, false)
          end

          def initialize_unsigned_headers(options)
            headers = Set.new(options.fetch(:unsigned_headers, []).map(&:downcase))
            headers.merge(%w[authorization x-amzn-trace-id expect])
          end

          # @return [String]
          attr_reader :service

          # @return [String]
          attr_reader :region

          # @return [#credentials] Returns an object that responds to
          #   `#credentials`, returning an object that responds to the following
          #   methods:
          #
          #   * `#access_key_id` => String
          #   * `#secret_access_key` => String
          #   * `#session_token` => String, nil
          #   * `#set?` => Boolean
          #
          attr_reader :credentials_provider

          # @return [Set<String>] Returns a set of header names that should not be signed.
          #   All header names have been downcased.
          attr_reader :unsigned_headers

          # @return [Boolean] When `true` the `x-amz-content-sha256` header will be signed and
          #   returned in the signature headers.
          attr_reader :apply_checksum_header

          # Computes a version 4 signature signature. Returns the resultant
          # signature as a hash of headers to apply to your HTTP request. The given
          # request is not modified.
          #
          #     signature = signer.sign_request(
          #       http_method: 'PUT',
          #       url: 'https://domain.com',
          #       headers: {
          #         'Abc' => 'xyz',
          #       },
          #       body: 'body' # String or IO object
          #     )
          #
          #     # Apply the following hash of headers to your HTTP request
          #     signature.headers['host']
          #     signature.headers['x-amz-date']
          #     signature.headers['x-amz-security-token']
          #     signature.headers['x-amz-content-sha256']
          #     signature.headers['authorization']
          #
          # In addition to computing the signature headers, the canonicalized
          # request, string to sign and content sha256 checksum are also available.
          # These values are useful for debugging signature errors returned by AWS.
          #
          #     signature.canonical_request #=> "..."
          #     signature.string_to_sign #=> "..."
          #     signature.content_sha256 #=> "..."
          #
          # @param [Hash] request
          #
          # @option request [required, String] :http_method One of
          #   'GET', 'HEAD', 'PUT', 'POST', 'PATCH', or 'DELETE'
          #
          # @option request [required, String, URI::HTTP, URI::HTTPS] :url
          #   The request URI. Must be a valid HTTP or HTTPS URI.
          #
          # @option request [optional, Hash] :headers ({}) A hash of headers
          #   to sign. If the 'X-Amz-Content-Sha256' header is set, the `:body`
          #   is optional and will not be read.
          #
          # @option request [optional, String, IO] :body ('') The HTTP request body.
          #   A sha256 checksum is computed of the body unless the
          #   'X-Amz-Content-Sha256' header is set.
          #
          # @return [Signature] Return an instance of {Signature} that has
          #   a `#headers` method. The headers must be applied to your request.
          #
          def sign_request(request)
            creds = fetch_credentials.first
            request_components = extract_request_components(request)
            sigv4_headers = build_sigv4_headers(request_components, creds)
            signature = compute_signature(request_components, creds, sigv4_headers)

            build_signature_response(request_components, sigv4_headers, signature)
          end

          private

          def extract_request_components(request)
            http_method = extract_http_method(request)
            url = extract_url(request)
            Signer.normalize_path(url) if @normalize_path
            headers = downcase_headers(request[:headers])

            build_request_components(http_method, url, headers, request[:body])
          end

          def build_request_components(http_method, url, headers, body)
            datetime = extract_datetime(headers)
            content_sha256 = extract_content_sha256(headers, body)

            {
              http_method: http_method,
              url: url,
              headers: headers,
              datetime: datetime,
              date: datetime[0, 8],
              content_sha256: content_sha256
            }
          end

          def extract_datetime(headers)
            headers['x-amz-date'] || Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
          end

          def extract_content_sha256(headers, body)
            headers['x-amz-content-sha256'] || sha256_hexdigest(body || '')
          end

          def build_sigv4_headers(components, creds)
            headers = {
              'host' => components[:headers]['host'] || host(components[:url]),
              'x-amz-date' => components[:datetime]
            }

            add_session_token_header(headers, creds)
            add_content_sha256_header(headers, components[:content_sha256])
            add_region_header(headers)

            headers
          end

          def add_session_token_header(headers, creds)
            return unless creds.session_token && !@omit_session_token

            if @signing_algorithm == :'sigv4-s3express'
              headers['x-amz-s3session-token'] = creds.session_token
            else
              headers['x-amz-security-token'] = creds.session_token
            end
          end

          def add_content_sha256_header(headers, content_sha256)
            headers['x-amz-content-sha256'] = content_sha256 if @apply_checksum_header
          end

          def add_region_header(headers)
            headers['x-amz-region-set'] = @region if @signing_algorithm == :sigv4a && @region && !@region.empty?
          end

          def compute_signature(components, creds, sigv4_headers)
            algorithm = sts_algorithm
            headers = components[:headers].merge(sigv4_headers)

            signature_components = build_signature_components(
              components, creds, headers, algorithm
            )

            build_signature_result(signature_components, headers, creds, components[:date])
          end

          def build_signature_components(components, creds, headers, algorithm)
            creq = canonical_request(
              components[:http_method],
              components[:url],
              headers,
              components[:content_sha256]
            )
            sts = string_to_sign(components[:datetime], creq, algorithm)
            sig = generate_signature(creds, components[:date], sts)

            {
              creq: creq,
              sts: sts,
              sig: sig
            }
          end

          def build_signature_result(components, headers, creds, date)
            algorithm = sts_algorithm
            {
              algorithm: algorithm,
              credential: credential(creds, date),
              signed_headers: signed_headers(headers),
              signature: components[:sig],
              canonical_request: components[:creq],
              string_to_sign: components[:sts]
            }
          end

          def generate_signature(creds, date, string_to_sign)
            if @signing_algorithm == :sigv4a
              asymmetric_signature(creds, string_to_sign)
            else
              signature(creds.secret_access_key, date, string_to_sign)
            end
          end

          def build_signature_response(components, sigv4_headers, signature)
            headers = build_headers(sigv4_headers, signature, components)

            Signature.new(
              headers: headers,
              string_to_sign: signature[:string_to_sign],
              canonical_request: signature[:canonical_request],
              content_sha256: components[:content_sha256],
              signature: signature[:signature]
            )
          end

          def build_headers(sigv4_headers, signature, components)
            headers = sigv4_headers.merge(
              'authorization' => build_authorization_header(signature)
            )

            add_omitted_session_token(headers, components[:creds]) if @omit_session_token
            headers
          end

          def build_authorization_header(signature)
            [
              "#{signature[:algorithm]} Credential=#{signature[:credential]}",
              "SignedHeaders=#{signature[:signed_headers]}",
              "Signature=#{signature[:signature]}"
            ].join(', ')
          end

          def add_omitted_session_token(headers, creds)
            return unless creds&.session_token

            headers['x-amz-security-token'] = creds.session_token
          end

          def sts_algorithm
            @signing_algorithm == :sigv4a ? 'AWS4-ECDSA-P256-SHA256' : 'AWS4-HMAC-SHA256'
          end

          def canonical_request(http_method, url, headers, content_sha256)
            [
              http_method,
              path(url),
              normalized_querystring(url.query || ''),
              "#{canonical_headers(headers)}\n",
              signed_headers(headers),
              content_sha256
            ].join("\n")
          end

          def string_to_sign(datetime, canonical_request, algorithm)
            [
              algorithm,
              datetime,
              credential_scope(datetime[0, 8]),
              sha256_hexdigest(canonical_request)
            ].join("\n")
          end

          def credential_scope(date)
            [
              date,
              (@region unless @signing_algorithm == :sigv4a),
              @service,
              'aws4_request'
            ].compact.join('/')
          end

          def credential(credentials, date)
            "#{credentials.access_key_id}/#{credential_scope(date)}"
          end

          def signature(secret_access_key, date, string_to_sign)
            k_date = hmac("AWS4#{secret_access_key}", date)
            k_region = hmac(k_date, @region)
            k_service = hmac(k_region, @service)
            k_credentials = hmac(k_service, 'aws4_request')
            hexhmac(k_credentials, string_to_sign)
          end

          def asymmetric_signature(creds, string_to_sign)
            ec, = Aws::Sigv4::AsymmetricCredentials.derive_asymmetric_key(
              creds.access_key_id, creds.secret_access_key
            )
            sts_digest = OpenSSL::Digest::SHA256.digest(string_to_sign)
            s = ec.dsa_sign_asn1(sts_digest)

            Digest.hexencode(s)
          end

          def path(url)
            path = url.path
            path = '/' if path == ''
            if @uri_escape_path
              uri_escape_path(path)
            else
              path
            end
          end

          def normalized_querystring(querystring)
            params = normalize_params(querystring)
            sort_params(params).map(&:first).join('&')
          end

          def normalize_params(querystring)
            params = querystring.split('&')
            params.map { |p| ensure_param_has_equals(p) }
          end

          def ensure_param_has_equals(param)
            param.match(/=/) ? param : "#{param}="
          end

          # From: https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
          # Sort the parameter names by character code point in ascending order.
          # Parameters with duplicate names should be sorted by value.
          # When names match, sort by values. When values also match,
          # preserve original order to maintain stable sorting.
          def sort_params(params)
            params.each.with_index.sort do |a, b|
              compare_params(a, b)
            end
          end

          def compare_params(param_pair1, param_pair2)
            param1, offset1 = param_pair1
            param2, offset2 = param_pair2
            name1, value1 = param1.split('=')
            name2, value2 = param2.split('=')

            compare_param_components(
              ParamComponent.new(name1, value1, offset1),
              ParamComponent.new(name2, value2, offset2)
            )
          end

          def compare_param_components(component1, component2)
            if component1.name == component2.name
              if component1.value == component2.value
                component1.offset <=> component2.offset
              else
                component1.value <=> component2.value
              end
            else
              component1.name <=> component2.name
            end
          end

          def signed_headers(headers)
            headers.inject([]) do |signed_headers, (header, _)|
              if @unsigned_headers.include?(header)
                signed_headers
              else
                signed_headers << header
              end
            end.sort.join(';')
          end

          def canonical_headers(headers)
            headers = headers.inject([]) do |hdrs, (k, v)|
              if @unsigned_headers.include?(k)
                hdrs
              else
                hdrs << [k, v]
              end
            end
            headers = headers.sort_by(&:first)
            headers.map { |k, v| "#{k}:#{canonical_header_value(v.to_s)}" }.join("\n")
          end

          def canonical_header_value(value)
            value.gsub(/\s+/, ' ').strip
          end

          def host(uri)
            # Handles known and unknown URI schemes; default_port nil when unknown.
            if uri.default_port == uri.port
              uri.host
            else
              "#{uri.host}:#{uri.port}"
            end
          end

          # @param [File, Tempfile, IO#read, String] value
          # @return [String<SHA256 Hexdigest>]
          def sha256_hexdigest(value)
            if file_like?(value)
              digest_file(value)
            elsif value.respond_to?(:read)
              digest_io(value)
            else
              digest_string(value)
            end
          end

          def file_like?(value)
            (value.is_a?(File) || value.is_a?(Tempfile)) && !value.path.nil? && File.exist?(value.path)
          end

          def digest_file(value)
            OpenSSL::Digest::SHA256.file(value).hexdigest
          end

          def digest_io(value)
            sha256 = OpenSSL::Digest.new('SHA256')
            update_digest_from_io(sha256, value)
            value.rewind
            sha256.hexdigest
          end

          def update_digest_from_io(digest, io)
            while (chunk = io.read(1024 * 1024)) # 1MB
              digest.update(chunk)
            end
          end

          def digest_string(value)
            OpenSSL::Digest::SHA256.hexdigest(value)
          end

          def hmac(key, value)
            OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value)
          end

          def hexhmac(key, value)
            OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), key, value)
          end

          def extract_service(options)
            if options[:service]
              options[:service]
            else
              msg = 'missing required option :service'
              raise ArgumentError, msg
            end
          end

          def extract_region(options)
            raise Errors::MissingRegionError unless options[:region]

            options[:region]
          end

          def extract_credentials_provider(options)
            if options[:credentials_provider]
              options[:credentials_provider]
            elsif options.key?(:credentials) || options.key?(:access_key_id)
              StaticCredentialsProvider.new(options)
            else
              raise Errors::MissingCredentialsError
            end
          end

          def extract_http_method(request)
            if request[:http_method]
              request[:http_method].upcase
            else
              msg = 'missing required option :http_method'
              raise ArgumentError, msg
            end
          end

          def extract_url(request)
            if request[:url]
              URI.parse(request[:url].to_s)
            else
              msg = 'missing required option :url'
              raise ArgumentError, msg
            end
          end

          def downcase_headers(headers)
            (headers || {}).to_hash.transform_keys(&:downcase)
          end

          def extract_expires_in(options)
            case options[:expires_in]
            when nil then 900
            when Integer then options[:expires_in]
            else
              msg = 'expected :expires_in to be a number of seconds'
              raise ArgumentError, msg
            end
          end

          def uri_escape(string)
            self.class.uri_escape(string)
          end

          def uri_escape_path(string)
            self.class.uri_escape_path(string)
          end

          def fetch_credentials
            credentials = @credentials_provider.credentials
            if credentials_set?(credentials)
              expiration = nil
              expiration = @credentials_provider.expiration if @credentials_provider.respond_to?(:expiration)
              [credentials, expiration]
            else
              raise Errors::MissingCredentialsError,
                    'unable to sign request without credentials set'
            end
          end

          # Returns true if credentials are set (not nil or empty)
          # Credentials may not implement the Credentials interface
          # and may just be credential like Client response objects
          # (eg those returned by sts#assume_role)
          def credentials_set?(credentials)
            !credentials.access_key_id.nil? &&
              !credentials.access_key_id.empty? &&
              !credentials.secret_access_key.nil? &&
              !credentials.secret_access_key.empty?
          end

          def presigned_url_expiration(options, expiration, datetime)
            expires_in = extract_expires_in(options)
            return expires_in unless expiration

            expiration_seconds = (expiration - datetime).to_i
            # In the static stability case, credentials may expire in the past
            # but still be valid.  For those cases, use the user configured
            # expires_in and ingore expiration.
            if expiration_seconds <= 0
              expires_in
            else
              [expires_in, expiration_seconds].min
            end
          end

          class << self
            # Kept for backwards compatability
            # Always return false since we are not using crt signing functionality
            def use_crt?
              false
            end

            # @api private
            def uri_escape_path(path)
              path.gsub(%r{[^/]+}) { |part| uri_escape(part) }
            end

            # @api private
            def uri_escape(string)
              if string.nil?
                nil
              else
                CGI.escape(string.encode('UTF-8')).gsub('+', '%20').gsub('%7E', '~')
              end
            end

            # @api private
            def normalize_path(uri)
              normalized_path = Pathname.new(uri.path).cleanpath.to_s
              # Pathname is probably not correct to use. Empty paths will
              # resolve to "." and should be disregarded
              normalized_path = '' if normalized_path == '.'
              # Ensure trailing slashes are correctly preserved
              normalized_path << '/' if uri.path.end_with?('/') && !normalized_path.end_with?('/')
              uri.path = normalized_path
            end
          end
        end
      end
    end
  end
end
