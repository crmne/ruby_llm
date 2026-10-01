# frozen_string_literal: true

require 'digest'
require 'stringio'

module RubyLLM
  module Providers
    class VertexAI
      # Google credentials shared by every Vertex AI provider in the process.
      # googleauth keeps the access token on the credentials object and
      # refreshes it a minute before it expires, so sharing the object shares
      # the token.
      class Credentials # :nodoc:
        CACHE = Support::ProcessCache.new

        attr_reader :authorizer

        def self.for(config)
          key = config.vertexai_service_account_key
          CACHE.fetch([source(key), SCOPES]) { new(key) }
        end

        def self.cache
          CACHE
        end

        def self.source(key)
          return Digest::SHA256.hexdigest(key) if key

          [:application_default, ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil)]
        end
        private_class_method :source

        def initialize(service_account_key)
          @authorizer = build(service_account_key)
          @lock = Mutex.new
        end

        # One caller fetches an expiring token while the others wait for it.
        def headers
          @lock.synchronize { @authorizer.apply({}) }
        end

        private

        def build(service_account_key)
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
