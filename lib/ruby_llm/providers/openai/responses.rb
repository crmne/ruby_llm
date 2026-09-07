# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # OpenAI's Responses API, including input-token counting.
      class Responses < Protocols::Responses
        include Protocols::Responses::TokenCounting
        include Protocols::Responses::Compaction
      end
    end
  end
end
