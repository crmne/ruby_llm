# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Mantle
        # The OpenAI Chat Completions API on the bedrock-mantle endpoint,
        # which serves most of mantle's non-Claude catalog.
        class ChatCompletions < Protocols::ChatCompletions
          include Mantle

          def completion_url
            'v1/chat/completions'
          end

          def supports_provider_file_references?
            false
          end
        end
      end
    end
  end
end
