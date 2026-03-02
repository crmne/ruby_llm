# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Helper for constructing Anthropic native content blocks.
      class Content
        class << self
          def new(text = nil, cache: false, cache_control: nil, parts: nil, **extras)
            payload = resolve_payload(
              text: text,
              parts: parts,
              cache: cache,
              cache_control: cache_control,
              extras: extras
            )

            RubyLLM::Content::Raw.new(payload)
          end

          private

          def resolve_payload(text:, parts:, cache:, cache_control:, extras:)
            return Array(parts) if parts

            raise ArgumentError, 'text or parts must be provided' if text.nil?

            block = { type: 'text', text: text }.merge(extras)
            control = determine_cache_control(cache_control, cache)
            block[:cache_control] = control if control

            [block]
          end

          def determine_cache_control(cache_control, cache_flag)
            return cache_control if cache_control

            { type: 'ephemeral' } if cache_flag
          end
        end
      end
    end
  end
end
