# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Shared SigV4-signed runtime requests for Bedrock protocols.
      module SignedRequests
        private

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
end
