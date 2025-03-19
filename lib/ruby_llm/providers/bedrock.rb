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
      extend Bedrock::Signing

      def self.extended(base)
        base.extend(Provider)
        base.extend(Bedrock::Chat)
        base.extend(Bedrock::Streaming)
        base.extend(Bedrock::Models)
        base.extend(Bedrock::Tools)
        base.extend(Bedrock::Signing)
      end

      module_function

      def api_base
        @api_base ||= "https://bedrock-runtime.#{aws_region}.amazonaws.com"
      end

      def post(url, payload)
        connection.post url, payload do |req|
          req.headers.merge! headers(method: :post,
                                     path: "#{connection.url_prefix}#{url}",
                                     body: payload.to_json,
                                     streaming: block_given?)
          yield req if block_given?
        end
      end

      def headers(method: :post, path: nil, body: nil, streaming: false)
        signer = Signing::Signer.new({
                                       access_key_id: aws_access_key_id,
                                       secret_access_key: aws_secret_access_key,
                                       session_token: aws_session_token,
                                       region: aws_region,
                                       service: 'bedrock'
                                     })
        request = {
          connection: connection,
          http_method: method,
          url: path || completion_url,
          body: body || ''
        }
        signature = signer.sign_request(request)

        accept_header = streaming ? 'application/vnd.amazon.eventstream' : 'application/json'

        signature.headers.merge(
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
        ENV['AWS_REGION'] || 'us-east-1'
      end

      def aws_access_key_id
        ENV.fetch('AWS_ACCESS_KEY_ID', nil)
      end

      def aws_secret_access_key
        ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
      end

      def aws_session_token
        ENV.fetch('AWS_SESSION_TOKEN', nil)
      end

      class Error < RubyLLM::Error; end
    end
  end
end
