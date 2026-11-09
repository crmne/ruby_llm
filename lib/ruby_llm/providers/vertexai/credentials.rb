# frozen_string_literal: true

require 'digest'
require 'stringio'

module RubyLLM
  module Providers
    class VertexAI
      # Google credentials shared by every Vertex AI provider in the process.
      # googleauth keeps the access token on the credentials object and
      # refreshes it a minute before it expires, so sharing the object shares
      # the token. With a token timeout, token requests go through the
      # middleware and adapter of Faraday's default connection, as googleauth's
      # own would, with that timeout and its proxy. Faraday 1 drops a
      # builder's adapter when it duplicates a builder without middleware, so
      # the builder is shared, not duplicated. The connection is built for
      # each token fetch, so it takes the proxy the default connection would
      # use at that moment, from its settings or the environment.
      class Credentials # :nodoc:
        CACHE = Support::ProcessCache.new

        attr_reader :authorizer

        def self.for(config)
          key = config.vertexai_service_account_key
          timeout = config.vertexai_token_timeout
          CACHE.fetch([source(key), SCOPES, timeout]) { new(key, token_timeout: timeout) }
        end

        def self.cache
          CACHE
        end

        def self.source(key)
          return Digest::SHA256.hexdigest(key) if key

          [:application_default, ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil)]
        end
        private_class_method :source

        def initialize(service_account_key, token_timeout: nil)
          @token_timeout = token_timeout
          @authorizer = build(service_account_key)
          @lock = Mutex.new
        end

        # One caller fetches an expiring token while the others wait for it.
        def headers
          @lock.synchronize { @authorizer.apply({}) }
        end

        private

        def build(service_account_key)
          authorizer = google_credentials(service_account_key)
          return authorizer unless @token_timeout && authorizer.respond_to?(:configure_connection)

          authorizer.configure_connection(connection_builder: method(:token_connection))
          authorizer
        end

        def token_connection
          default = Faraday.default_connection
          connection = Faraday.new(builder: default.builder, headers: default.headers, params: default.params,
                                   ssl: default.ssl, request: default.options.merge(timeout: @token_timeout))
          connection.proxy = default.proxy_for_request(@authorizer.token_credential_uri.to_s)
          connection
        end

        def google_credentials(service_account_key)
          require 'googleauth'
          if service_account_key
            ::Google::Auth::ServiceAccountCredentials.make_creds(
              json_key_io: StringIO.new(service_account_key),
              scope: SCOPES
            )
          else
            ::Google::Auth.get_application_default(SCOPES)
          end
        rescue LoadError
          raise Error,
                'The googleauth gem ~> 1.15 is required for Vertex AI. Please add it to your Gemfile: gem "googleauth"'
        end
      end
    end
  end
end
