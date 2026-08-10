# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # The Anthropic Messages API on the bedrock-mantle endpoint, which
      # serves Claude generations from Opus 4.7 onward. Requests are
      # SigV4-signed for the bedrock-mantle service.
      class Mantle < Protocols::Anthropic
        SIGNING_SERVICE = 'bedrock-mantle'

        def initialize(provider, model = nil)
          super
          @connection = provider.mantle_connection
        end

        def completion_url
          'anthropic/v1/messages'
        end

        def count_tokens_url
          'anthropic/v1/messages/count_tokens'
        end

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
            req.headers.merge!(mantle_headers(url, body))
            req.headers.merge!(additional_headers) unless additional_headers.empty?
          end
        end

        def stream_response(payload, additional_headers = {}, &)
          body = JSON.generate(payload)
          super(payload, mantle_headers(stream_url, body).merge(additional_headers), &)
        end

        def mantle_headers(url, body)
          @provider.sign_headers('POST', url, body, base_url: @provider.mantle_api_base, service: SIGNING_SERVICE)
                   .merge('anthropic-version' => '2023-06-01')
        end
      end
    end
  end
end
