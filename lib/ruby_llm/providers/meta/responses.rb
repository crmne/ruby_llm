# frozen_string_literal: true

module RubyLLM
  module Providers
    class Meta
      # Meta's dialect of the OpenAI Responses API, the format Meta
      # recommends because it replays encrypted reasoning across turns.
      # https://dev.meta.ai/docs/protocols/responses
      class Responses < Protocols::Responses
        include Protocols::Responses::TokenCounting

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } }
        }.freeze

        PROMPT_CACHE_OPTIONS = %i[key ttl].freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def apply_end_user(payload, identifier)
          payload.merge(safety_identifier: identifier)
        end

        # Meta takes a cache key and a retention hint, in_memory or 24h,
        # and no cache breakpoints.
        def prompt_cache_params(caching)
          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          unless unsupported.empty?
            raise ArgumentError,
                  "Meta prompt caching accepts :key and :ttl, got #{format_cache_option_keys(unsupported)}"
          end

          { prompt_cache_key: options[:key], prompt_cache_retention: options[:ttl] }.compact
        end

        def inject_cache_breakpoint(item)
          item
        end
      end
    end
  end
end
