# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Mantle
        # The Anthropic Messages API on the bedrock-mantle endpoint, which
        # serves Claude generations from Opus 4.7 onward.
        class Anthropic < Protocols::Anthropic
          include Mantle

          ANTHROPIC_VERSION = '2023-06-01'

          def completion_url
            'anthropic/v1/messages'
          end

          def count_tokens_url
            'anthropic/v1/messages/count_tokens'
          end

          private

          def post_count_tokens(payload)
            signed_post(count_tokens_url, payload)
          end

          def mantle_headers(url, body)
            super.merge('anthropic-version' => ANTHROPIC_VERSION)
          end
        end
      end
    end
  end
end
