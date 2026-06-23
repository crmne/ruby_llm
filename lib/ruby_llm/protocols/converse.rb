# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The AWS Bedrock Converse API. Requests are SigV4-signed by the provider.
    class Converse < Protocol
      include Converse::Chat
      include Converse::Embeddings
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
        response = signed_post(completion_url, payload, additional_headers)
        parse_completion_response(response)
      end

      def signed_post(url, payload, additional_headers = {})
        body = JSON.generate(payload)

        @connection.post(url, payload) do |req|
          req.headers.merge!(@provider.sign_headers('POST', url, body))
          req.headers.merge!(additional_headers) unless additional_headers.empty?
        end
      end
    end
  end
end
