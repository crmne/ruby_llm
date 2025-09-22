# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Handles caching of prompts for Anthropic
      module Cache
        def should_cache?(type)
          return false unless cache_prompts
          return true if cache_prompts == true
          return true if cache_prompts.is_a?(Array) && cache_prompts.include?(type)
          return true if cache_prompts.is_a?(Symbol) && cache_prompts == type
          false
        end
      end
    end
  end
end