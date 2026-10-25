# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # OpenAI's Responses API, including input-token counting.
      class Responses < Protocols::Responses
        include Protocols::Responses::TokenCounting
        include Protocols::Responses::Compaction

        def document_urls?
          true
        end
      end
    end
  end
end
