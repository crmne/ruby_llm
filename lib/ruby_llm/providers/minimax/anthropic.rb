# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax's dialect of the Anthropic Messages API. MiniMax has no
      # Files API on this endpoint and none of Anthropic's server tools.
      class Anthropic < Protocols::Anthropic
        def server_tool_aliases
          nil
        end

        def provider_file_references?
          false
        end
      end
    end
  end
end
