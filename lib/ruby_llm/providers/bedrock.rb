# frozen_string_literal: true

require 'openssl'
require 'time'

module RubyLLM
  module Providers
    # AWS Bedrock API integration. Handles chat completion and streaming
    # for Claude and Titan models.
    module Bedrock
      extend Provider
      extend Bedrock::Chat
      extend Bedrock::Streaming
      extend Bedrock::Models
      extend Bedrock::Tools

      def self.extended(base)
        base.extend(Provider)
        base.extend(Bedrock::Chat)
        base.extend(Bedrock::Streaming)
        base.extend(Bedrock::Models)
        base.extend(Bedrock::Tools)
      end

      module_function

      def api_base
        "https://bedrock-runtime.#{aws_region}.amazonaws.com"
      end

      def headers
        SignatureV4.sign_request(
          connection: connection,
          method: :post,
          path: completion_url,
          body: '',
          access_key: aws_access_key_id,
          secret_key: aws_secret_access_key,
          session_token: aws_session_token,
          region: aws_region
        ).merge(
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        )
      end

      def capabilities
        Bedrock::Capabilities
      end

      def slug
        'bedrock'
      end

      def connection
        @connection ||= Faraday.new(url: api_base) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end

      def aws_region
        ENV['AWS_REGION'] || 'us-east-1'
      end

      def aws_access_key_id
        ENV['AWS_ACCESS_KEY_ID']
      end

      def aws_secret_access_key
        ENV['AWS_SECRET_ACCESS_KEY']
      end

      def aws_session_token
        ENV['AWS_SESSION_TOKEN']
      end

      class Error < RubyLLM::Error; end

      # AWS Signature V4 implementation
      module SignatureV4
        def self.sign_request(connection:, method:, path:, body: nil, access_key:, secret_key:, session_token: nil, region:, service: 'bedrock')
          now = Time.now.utc
          amz_date = now.strftime('%Y%m%dT%H%M%SZ')
          date = now.strftime('%Y%m%d')

          # Create canonical request
          canonical_headers = [
            "host:#{connection.url_prefix.host}",
            "x-amz-date:#{amz_date}"
          ]
          canonical_headers << "x-amz-security-token:#{session_token}" if session_token

          signed_headers = canonical_headers.map { |h| h.split(':')[0] }.sort.join(';')
          canonical_request = [
            method.to_s.upcase,
            path,
            '',
            canonical_headers.sort.join("\n") + "\n",
            signed_headers,
            body ? OpenSSL::Digest::SHA256.hexdigest(body) : OpenSSL::Digest::SHA256.hexdigest('')
          ].join("\n")

          # Create string to sign
          credential_scope = "#{date}/#{region}/#{service}/aws4_request"
          string_to_sign = [
            'AWS4-HMAC-SHA256',
            amz_date,
            credential_scope,
            OpenSSL::Digest::SHA256.hexdigest(canonical_request)
          ].join("\n")

          # Calculate signature
          k_date = hmac("AWS4#{secret_key}", date)
          k_region = hmac(k_date, region)
          k_service = hmac(k_region, service)
          k_signing = hmac(k_service, 'aws4_request')
          signature = hmac(k_signing, string_to_sign).unpack1('H*')

          # Create authorization header
          authorization = [
            "AWS4-HMAC-SHA256 Credential=#{access_key}/#{credential_scope}",
            "SignedHeaders=#{signed_headers}",
            "Signature=#{signature}"
          ].join(', ')

          headers = {
            'Authorization' => authorization,
            'x-amz-date' => amz_date
          }
          headers['x-amz-security-token'] = session_token if session_token

          headers
        end

        def self.hmac(key, value)
          OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value)
        end
      end
    end
  end
end 