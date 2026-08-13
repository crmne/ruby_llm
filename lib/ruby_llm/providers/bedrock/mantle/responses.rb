# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Mantle
        # The OpenAI Responses API on the bedrock-mantle endpoint, which
        # serves every non-Claude model mantle hosts: OpenAI, Qwen, Mistral,
        # DeepSeek, and the rest.
        class Responses < Protocols::Responses
          include Mantle

          def completion_url
            'v1/responses'
          end

          def supports_provider_file_references?
            false
          end
        end
      end
    end
  end
end
