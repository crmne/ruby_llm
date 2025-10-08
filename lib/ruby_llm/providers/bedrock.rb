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
      include Bedrock::Media
      include Anthropic::Tools

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
        signer_options = {
          region: @config.bedrock_region,
          service: 'bedrock'
        }

        if @config.bedrock_credential_provider
          validate_credential_provider!(@config.bedrock_credential_provider)
          signer_options[:credentials_provider] = @config.bedrock_credential_provider
        else
          signer_options.merge!({
                                  access_key_id: @config.bedrock_api_key,
                                  secret_access_key: @config.bedrock_secret_key,
                                  session_token: @config.bedrock_session_token
                                })
        end

        Signing::Signer.new(signer_options)
      end

      def validate_credential_provider!(provider)
        return if provider.respond_to?(:credentials)

        raise ConfigurationError,
              'bedrock_credential_provider must respond to :credentials method'
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

      def configuration_requirements
        # If credential provider is configured, only region is required
        # Otherwise, require static credentials (api_key, secret_key) + region
        if @config.bedrock_credential_provider
          %i[bedrock_region]
        else
          %i[bedrock_api_key bedrock_secret_key bedrock_region]
        end
      end

      class << self
        def capabilities
          Bedrock::Capabilities
        end

        def configuration_requirements
          %i[bedrock_region]
        end
      end
    end
  end
end
