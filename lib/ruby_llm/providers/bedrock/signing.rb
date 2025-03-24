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

          class MissingRegionError < ArgumentError
            def initialize(*_args)
              super('missing required option :region')
            end
          end
        end

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
            @unsigned_headers = Set.new(options.fetch(:unsigned_headers, []).map(&:downcase))
            @unsigned_headers << 'authorization'
            @unsigned_headers << 'x-amzn-trace-id'
            @unsigned_headers << 'expect'
            @uri_escape_path = options.fetch(:uri_escape_path, true)
            @apply_checksum_header = options.fetch(:apply_checksum_header, true)
            @signing_algorithm = options.fetch(:signing_algorithm, :sigv4)
            @normalize_path = options.fetch(:normalize_path, true)
            @omit_session_token = options.fetch(:omit_session_token, false)
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
            creds, = fetch_credentials

            http_method = extract_http_method(request)
            url = extract_url(request)
            Signer.normalize_path(url) if @normalize_path
            headers = downcase_headers(request[:headers])

            datetime = headers['x-amz-date']
            datetime ||= Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
            date = datetime[0, 8]

            content_sha256 = headers['x-amz-content-sha256']
            content_sha256 ||= sha256_hexdigest(request[:body] || '')

            sigv4_headers = {}
            sigv4_headers['host'] = headers['host'] || host(url)
            sigv4_headers['x-amz-date'] = datetime
            if creds.session_token && !@omit_session_token
              if @signing_algorithm == :'sigv4-s3express'
                sigv4_headers['x-amz-s3session-token'] = creds.session_token
              else
                sigv4_headers['x-amz-security-token'] = creds.session_token
              end
            end

            sigv4_headers['x-amz-content-sha256'] ||= content_sha256 if @apply_checksum_header

            sigv4_headers['x-amz-region-set'] = @region if @signing_algorithm == :sigv4a && @region && !@region.empty?
            headers = headers.merge(sigv4_headers) # merge so we do not modify given headers hash

            algorithm = sts_algorithm

            # compute signature parts
            creq = canonical_request(http_method, url, headers, content_sha256)
            sts = string_to_sign(datetime, creq, algorithm)

            sig =
              if @signing_algorithm == :sigv4a
                asymmetric_signature(creds, sts)
              else
                signature(creds.secret_access_key, date, sts)
              end

            algorithm = sts_algorithm

            # apply signature
            sigv4_headers['authorization'] = [
              "#{algorithm} Credential=#{credential(creds, date)}",
              "SignedHeaders=#{signed_headers(headers)}",
              "Signature=#{sig}"
            ].join(', ')

            # skip signing the session token, but include it in the headers
            sigv4_headers['x-amz-security-token'] = creds.session_token if creds.session_token && @omit_session_token

            # Returning the signature components.
            Signature.new(
              headers: sigv4_headers,
              string_to_sign: sts,
              canonical_request: creq,
              content_sha256: content_sha256,
              signature: sig
            )
          end

          private

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
            params = querystring.split('&')
            params = params.map { |p| p.match(/=/) ? p : "#{p}=" }
            # From: https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
            # Sort the parameter names by character code point in ascending order.
            # Parameters with duplicate names should be sorted by value.
            #
            # Default sort <=> in JRuby will swap members
            # occasionally when <=> is 0 (considered still sorted), but this
            # causes our normalized query string to not match the sent querystring.
            # When names match, we then sort by their values.  When values also
            # match then we sort by their original order
            params.each.with_index.sort do |a, b|
              a, a_offset = a
              b, b_offset = b
              a_name, a_value = a.split('=')
              b_name, b_value = b.split('=')
              if a_name == b_name
                if a_value == b_value
                  a_offset <=> b_offset
                else
                  a_value <=> b_value
                end
              else
                a_name <=> b_name
              end
            end.map(&:first).join('&')
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
            if (value.is_a?(File) || value.is_a?(Tempfile)) && !value.path.nil? && File.exist?(value.path)
              OpenSSL::Digest::SHA256.file(value).hexdigest
            elsif value.respond_to?(:read)
              sha256 = OpenSSL::Digest.new('SHA256')
              loop do
                chunk = value.read(1024 * 1024) # 1MB
                break unless chunk

                sha256.update(chunk)
              end
              value.rewind
              sha256.hexdigest
            else
              OpenSSL::Digest::SHA256.hexdigest(value)
            end
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
