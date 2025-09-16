# frozen_string_literal: true

require 'openssl'
require 'time'

module RubyLLM
  module Providers
    # AWS Bedrock API integration.
    class Bedrock < Provider
      include Bedrock::Chat
      include Bedrock::Streaming
      include Bedrock::Models
      include Bedrock::Signing
      include Bedrock::Tools
      include Bedrock::Media

      def api_base
        "https://bedrock-runtime.#{@config.bedrock_region}.amazonaws.com"
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          body['message']
        when Array
          body.map do |part|
            part['message']
          end.join('. ')
        else
          body
        end
      end

      def sign_request(url, method: :post, payload: nil)
        signer = create_signer
        request = build_request(url, method:, payload:)
        signer.sign_request(request)
      end

      def create_signer
        Signing::Signer.new({
                              access_key_id: @config.bedrock_api_key,
                              secret_access_key: @config.bedrock_secret_key,
                              session_token: @config.bedrock_session_token,
                              region: @config.bedrock_region,
                              service: 'bedrock'
                            })
      end

      def build_request(url, method: :post, payload: nil)
        {
          connection: @connection,
          http_method: method,
          url: url || completion_url,
          body: payload ? JSON.generate(payload, ascii_only: false) : nil
        }
      end

      def build_headers(signature_headers, streaming: false)
        accept_header = streaming ? 'application/vnd.amazon.eventstream' : 'application/json'

        signature_headers.merge(
          'Content-Type' => 'application/json',
          'Accept' => accept_header
        )
      end

      # Override to sign non-streaming Converse requests (ask)
      def sync_response(connection, payload, additional_headers = {})
        signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", payload:)

        response = connection.post completion_url, payload do |req|
          req.headers.merge! build_headers(signature.headers, streaming: false)
          req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
        end

        parse_completion_response response
      end

      class << self
        def capabilities
          Bedrock::Capabilities
        end

        def configuration_requirements
          %i[bedrock_api_key bedrock_secret_key bedrock_region]
        end
      end
    end
  end
end
