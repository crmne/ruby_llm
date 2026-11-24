# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # For hosts that do not fetch URLs: remote images and documents travel
      # as their bytes.
      module InlineSources # :nodoc:
        def render_payload(messages, **)
          payload = super
          payload[:messages] = inline_url_sources(payload[:messages])
          payload[:system] = inline_url_sources(payload[:system]) if payload[:system]
          payload
        end

        private

        def inline_url_sources(blocks)
          return blocks unless blocks.is_a?(Array)

          blocks.map do |block|
            next block unless block.is_a?(Hash)
            next inline_url_source(block) if url_source?(block)

            block[:content].is_a?(Array) ? block.merge(content: inline_url_sources(block[:content])) : block
          end
        end

        def url_source?(block)
          source = block[:source]
          source.is_a?(Hash) && source[:type] == 'url'
        end

        def inline_url_source(block)
          attachment = Attachment.new(block.dig(:source, :url))
          block.merge(source: { type: 'base64', media_type: attachment.mime_type, data: attachment.encoded })
        end
      end
    end
  end
end
