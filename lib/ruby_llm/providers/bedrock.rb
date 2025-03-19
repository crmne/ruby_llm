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
      extend Bedrock::Signature

      def self.extended(base)
        base.extend(Provider)
        base.extend(Bedrock::Chat)
        base.extend(Bedrock::Streaming)
        base.extend(Bedrock::Models)
        base.extend(Bedrock::Tools)
        base.extend(Bedrock::Signature)
      end

      module_function

      def api_base
        "https://bedrock.#{aws_region}.amazonaws.com"
        #"https://bedrock-runtime.#{aws_region}.amazonaws.com"
      end

      def headers(method: :post, path: nil, model_id: nil)
        Signature.sign_request(
          connection: connection,
          method: method,
          path: path || completion_url,
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

    end
  end
end 