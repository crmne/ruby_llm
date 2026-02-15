# frozen_string_literal: true

require 'digest'
require 'openssl'

module RubyLLM
  module Providers
    class Bedrock
      # SigV4 authentication helpers for Bedrock.
      module Auth
        private

        def signed_post(connection, url, payload, additional_headers = {})
          request_payload = api_payload(payload)
          body = JSON.generate(request_payload)
          signed_headers = sign_headers('POST', url, body)

          response = connection.post(url, request_payload) do |req|
            req.headers.merge!(signed_headers)
            req.headers.merge!(additional_headers) unless additional_headers.empty?
            yield req if block_given?
          end

          parse_completion_response(response)
        end

        def signed_get(base_url, url)
          conn = Connection.basic do |f|
            f.request :json
            f.response :json
            f.adapter :net_http
            f.use :llm_errors, provider: self
          end

          conn.url_prefix = base_url

          conn.get(url) do |req|
            req.headers.merge!(sign_headers('GET', url, '', base_url: base_url))
          end
        end

        def sign_headers(method, path, body, base_url: api_base)
          now = Time.now.utc
          amz_date = now.strftime('%Y%m%dT%H%M%SZ')
          date_stamp = now.strftime('%Y%m%d')

          uri = URI.parse(path)
          canonical_uri = canonical_uri(uri.path)
          canonical_query = canonical_query_string(uri.query)
          payload_hash = Digest::SHA256.hexdigest(body)

          headers = {
            'host' => URI.parse(base_url).host,
            'x-amz-content-sha256' => payload_hash,
            'x-amz-date' => amz_date
          }
          headers['x-amz-security-token'] = @config.bedrock_session_token if @config.bedrock_session_token

          signed_headers = headers.keys.sort.join(';')
          canonical_headers = headers.keys.sort.map { |key| "#{key}:#{headers[key].to_s.strip}\n" }.join

          canonical_request = [
            method,
            canonical_uri,
            canonical_query,
            canonical_headers,
            signed_headers,
            payload_hash
          ].join("\n")

          credential_scope = "#{date_stamp}/#{bedrock_region}/bedrock/aws4_request"
          string_to_sign = [
            'AWS4-HMAC-SHA256',
            amz_date,
            credential_scope,
            Digest::SHA256.hexdigest(canonical_request)
          ].join("\n")

          signing_key = signing_key(date_stamp)
          signature = OpenSSL::HMAC.hexdigest('sha256', signing_key, string_to_sign)

          {
            'X-Amz-Date' => amz_date,
            'X-Amz-Content-Sha256' => payload_hash,
            'X-Amz-Security-Token' => @config.bedrock_session_token,
            'Authorization' => "AWS4-HMAC-SHA256 Credential=#{@config.bedrock_api_key}/#{credential_scope}, " \
                               "SignedHeaders=#{signed_headers}, Signature=#{signature}",
            'Content-Type' => 'application/json'
          }.compact
        end

        def canonical_query_string(raw_query)
          return '' if raw_query.nil? || raw_query.empty?

          URI.decode_www_form(raw_query)
             .sort_by(&:first)
             .map { |k, v| "#{uri_encode(k)}=#{uri_encode(v)}" }
             .join('&')
        end

        def canonical_uri(path)
          return '/' if path.nil? || path.empty?

          segments = path.split('/', -1).map { |segment| uri_encode(segment) }
          canonical = segments.join('/')
          canonical.start_with?('/') ? canonical : "/#{canonical}"
        end

        def uri_encode(text)
          URI.encode_www_form_component(text.to_s).gsub('+', '%20').gsub('%7E', '~')
        end

        def signing_key(date_stamp)
          k_date = OpenSSL::HMAC.digest('sha256', "AWS4#{@config.bedrock_secret_key}", date_stamp)
          k_region = OpenSSL::HMAC.digest('sha256', k_date, bedrock_region)
          k_service = OpenSSL::HMAC.digest('sha256', k_region, 'bedrock')
          OpenSSL::HMAC.digest('sha256', k_service, 'aws4_request')
        end
      end
    end
  end
end
