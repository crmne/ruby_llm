# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS Bedrock Converse API. Requests are SigV4-signed by the provider.
    class Converse < Protocol
      include Converse::Chat
      include Converse::Media
      include Converse::Streaming

      def self.reasoning_embedded?(model)
        metadata = RubyLLM::Utils.deep_symbolize_keys(model.metadata || {})
        converse = metadata[:converse] || {}
        reasoning_supported = converse[:reasoningSupported] || {}
        reasoning_supported[:embedded] || false
      end

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
