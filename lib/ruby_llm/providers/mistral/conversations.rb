# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Mistral Conversations with its document and image attachment formats.
      class Conversations < Protocols::Mistral::Conversations
        include Mistral::Media
      end
    end
  end
end
