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
        body = JSON.generate(payload)
        response = @connection.post(completion_url, payload) do |req|
          req.headers.merge!(@provider.sign_headers('POST', completion_url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
        parse_completion_response(response)
      end
    end
  end
end
