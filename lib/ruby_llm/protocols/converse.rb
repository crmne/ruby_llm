# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS Bedrock Converse API. Requests are SigV4-signed by the provider.
    class Converse < Protocol
      include Converse::Chat
      include Converse::Media
      include Converse::Streaming

      private

      def sync_response(payload, additional_headers = {})
        response = signed_post(completion_url, payload, additional_headers)
        parse_completion_response(response)
      end

      def post_count_tokens(payload)
        signed_post(count_tokens_url, payload)
      end

      def signed_post(url, payload, additional_headers = {})
        body = JSON.generate(payload)

        @connection.post(url, payload, usage: @usage_tracker) do |req|
          req.headers.merge!(@provider.sign_headers('POST', url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
      end
    end
  end
end
