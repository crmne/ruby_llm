# frozen_string_literal: true

require 'openssl'
require 'time'

module RubyLLM
  module Providers
    # AWS Bedrock API integration. Handles chat completion and streaming
    # for Claude models.
    module Bedrock
      extend Provider
      extend Bedrock::Chat
      extend Bedrock::Streaming
      extend Bedrock::Models
      extend Bedrock::Signing

      # This provider currently only supports Anthropic models, so the tools/media implementation is shared
      extend Anthropic::Media
      extend Anthropic::Tools

      module_function

      def api_base
        @api_base ||= "https://bedrock-runtime.#{aws_region}.amazonaws.com"
      end

      def post(url, payload)
        signature = sign_request(url, payload, streaming: block_given?)
        
        connection.post url, payload do |req|
          req.headers.merge! build_headers(signature.headers, streaming: block_given?)
          yield req if block_given?
        end
      end

      def sign_request(url, payload, streaming: false)
        signer = Signing::Signer.new({
          access_key_id: aws_access_key_id,
          secret_access_key: aws_secret_access_key,
          session_token: aws_session_token,
          region: aws_region,
          service: 'bedrock'
        })

        request = {
          connection: connection,
          http_method: :post,
          url: url || completion_url,
          body: payload&.to_json || ''
        }

        signer.sign_request(request)
      end

      def build_headers(signature_headers, streaming: false)
        accept_header = streaming ? 'application/vnd.amazon.eventstream' : 'application/json'

        signature_headers.merge(
          'Content-Type' => 'application/json',
          'Accept' => accept_header
        )
      end

      def capabilities
        Bedrock::Capabilities
      end

      def slug
        'bedrock'
      end

      def aws_region
        RubyLLM.config.bedrock_region
      end

      def aws_access_key_id
        RubyLLM.config.bedrock_api_key
      end

      def aws_secret_access_key
        RubyLLM.config.bedrock_secret_key
      end

      def aws_session_token
        RubyLLM.config.bedrock_session_token
      end

      def configuration_requirements
        %i[bedrock_api_key bedrock_secret_key bedrock_region]
      end
    end
  end
end
