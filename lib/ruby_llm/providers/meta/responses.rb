# frozen_string_literal: true

module RubyLLM
  module Providers
    class Meta
      # Meta's dialect of the OpenAI Responses API, the format Meta
      # recommends because it replays encrypted reasoning across turns.
      # https://dev.meta.ai/docs/protocols/responses
      class Responses < Protocols::Responses
        include Protocols::Responses::TokenCounting
        include Protocols::Meta::Transcription

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } }
        }.freeze

        PROMPT_CACHE_OPTIONS = %i[key ttl].freeze
        AUDIO_FORMATS = %w[mp3 wav].freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def document_urls?
          true
        end

        def web_search_sources?
          true
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

          ttl = options[:ttl] && render_cache_lifetime(options[:ttl])
          { prompt_cache_key: options[:key], prompt_cache_retention: ttl }.compact
        end

        def cache_option_names = PROMPT_CACHE_OPTIONS

        def inject_cache_breakpoint(item)
          item
        end

        def supported_attachment?(attachment)
          return super if attachment.provider_file?
          return AUDIO_FORMATS.include?(attachment.format) if attachment.audio?

          attachment.video? || super
        end

        # Meta's fetcher is refused by many hosts, so remote media travels inline.
        def render_attachment(attachment)
          return super if attachment.provider_file? || !supported_attachment?(attachment)

          case attachment.type
          when :video then { type: 'input_video', video_url: attachment.for_llm }
          when :audio then { type: 'input_audio', input_audio: { data: attachment.encoded, format: attachment.format } }
          else super
          end
        end

        # Meta refuses to fetch many remote images, so images travel inline.
        def render_image(image, image_url: image.for_llm, **)
          super
        end
      end
    end
  end
end
