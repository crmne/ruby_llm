# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Shared plumbing for protocols served by the bedrock-mantle endpoint.
      # Mantle speaks the vendors' own wire formats rather than Converse, so
      # each protocol subclasses its family and mixes this in to borrow the
      # provider's mantle connection and SigV4-sign every request for the
      # bedrock-mantle service.
      module Mantle
        SIGNING_SERVICE = 'bedrock-mantle'

        # Mantle serves Claude on the Anthropic Messages API and everything
        # else on one of the two OpenAI surfaces. Only these models answer on
        # v1/responses; the rest of the non-Claude catalog answers on
        # v1/chat/completions and rejects v1/responses outright.
        RESPONSES_MODELS = %w[
          google.gemma-4-26b-a4b
          google.gemma-4-31b
          google.gemma-4-e2b
          openai.gpt-oss-20b
          openai.gpt-oss-120b
        ].freeze

        def initialize(provider, model = nil)
          super
          @connection = provider.mantle_connection
        end

        private

        def sync_response(payload, additional_headers = {})
          parse_completion_response signed_post(completion_url, payload, additional_headers)
        end

        def signed_post(url, payload, additional_headers = {})
          @connection.post(url, JSON.generate(payload), usage: @usage_tracker) do |req|
            req.headers.merge!(mantle_headers.merge(additional_headers))
          end
        end

        def stream_response(payload, additional_headers = {}, &)
          super(JSON.generate(payload), mantle_headers.merge(additional_headers), &)
        end

        def mantle_headers
          {}
        end
      end
    end
  end
end
