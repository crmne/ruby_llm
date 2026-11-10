# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax's dialect of the Anthropic Messages API. MiniMax has no
      # Files API on this endpoint, and web search is the one server tool it
      # runs, in Anthropic's first version.
      class Anthropic < Protocols::Anthropic
        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search_20250305', name: 'web_search' } }
        }.freeze

        def render_payload(messages, tools:, schema: nil, tool_prefs: nil, **)
          raise ArgumentError, "MiniMax's Messages API has no structured output" if schema
          raise ArgumentError, 'MiniMax does not accept calls: :one' if tools.any? && tool_prefs&.dig(:calls) == :one

          super
        end

        def render_count_tokens_payload(messages, tool_prefs: nil, **)
          super(messages, **, schema: nil, tool_prefs: tool_prefs&.except(:calls))
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def provider_file_references?
          false
        end

        def supported_attachment?(attachment)
          attachment.video? || super
        end

        private

        def render_content(content, attachments = [], citations: false)
          blocks = super(content, [], citations:)
          attachments.each do |attachment|
            blocks.concat(attachment.video? ? [render_video(attachment)] : super(nil, [attachment], citations:))
          end
          blocks
        end

        def append_formatted_content(content_blocks, msg, citations: false)
          content_blocks.concat(render_content(msg.content, msg.attachments, citations:))
        end

        def render_video(video)
          { type: 'video', source: video_source(video) }
        end

        # MiniMax's fetcher is refused by many hosts, so remote videos travel inline.
        def video_source(video)
          return { type: 'url', url: "mm_file://#{video.provider_file_id}" } if video.provider_file?

          media_type = video.mime_type == 'video/quicktime' ? 'video/mov' : video.mime_type
          { type: 'base64', media_type:, data: video.encoded }
        end
      end
    end
  end
end
