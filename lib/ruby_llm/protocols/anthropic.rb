# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Anthropic Messages API.
    class Anthropic < Protocol
      include Anthropic::Chat
      include Anthropic::Embeddings
      include Anthropic::Media
      include Anthropic::Models
      include Anthropic::Streaming
      include Anthropic::Tools

      # How many times a turn that stops with pause_turn is automatically
      # continued before RubyLLM returns what it has.
      MAX_PAUSE_TURN_CONTINUATIONS = 8

      # web_search/web_fetch pin allowed_callers to direct invocation: their
      # 2026 tool versions otherwise default to requiring programmatic tool
      # calling, which not every model supports.
      SERVER_TOOL_ALIASES = {
        web_search: { tool: { type: 'web_search_20260318', name: 'web_search', allowed_callers: ['direct'] } },
        web_fetch: { tool: { type: 'web_fetch_20260318', name: 'web_fetch', allowed_callers: ['direct'] } },
        url_context: { tool: { type: 'web_fetch_20260318', name: 'web_fetch', allowed_callers: ['direct'] } },
        code_execution: { tool: { type: 'code_execution_20260521', name: 'code_execution' } },
        mcp: lambda do |options|
          options = Utils.deep_symbolize_keys(options)
          name = options[:name] || 'mcp'
          server = { type: 'url', name: name }.merge(options.slice(:url, :authorization_token))
          {
            tool: { type: 'mcp_toolset', mcp_server_name: name }.merge(options.slice(:default_config, :configs)),
            payload: { mcp_servers: [server] },
            headers: { 'anthropic-beta' => 'mcp-client-2025-11-20' }
          }
        end
      }.freeze

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end

      # Server tools can pause a long turn with stop_reason pause_turn; the
      # API expects the conversation back verbatim to continue it. Segments
      # are merged into the single Message the caller sees.
      def complete(messages, ...)
        segments = []
        current_messages = messages

        MAX_PAUSE_TURN_CONTINUATIONS.times do
          message = super(current_messages, ...)
          segments << message
          break unless message.finish_reason == :pause_turn

          current_messages = current_messages + [message] # rubocop:disable Style/SelfAssignment
        end

        merge_turn_segments(segments)
      end

      private

      def sync_response(payload, additional_headers = {})
        super(payload, apply_files_beta(additional_headers, payload))
      end

      def stream_response(payload, additional_headers = {}, &)
        super(payload, apply_files_beta(additional_headers, payload), &)
      end

      def merge_turn_segments(segments)
        return segments.first if segments.one?

        final = segments.last
        Message.new(
          role: :assistant,
          content: segments.filter_map(&:content).join,
          citations: segments.flat_map(&:citations),
          server_tool_calls: segments.flat_map(&:server_tool_calls),
          raw_content: merge_raw_content(segments),
          thinking: final.thinking,
          tool_calls: merge_tool_calls(segments),
          tokens: Tokens.aggregate(segments.map(&:tokens)),
          finish_reason: final.finish_reason,
          model: final.model,
          raw: final.raw
        )
      end

      def merge_raw_content(segments)
        merged = segments.flat_map { |segment| segment.raw_content || [] }
        merged.empty? ? nil : merged
      end

      def merge_tool_calls(segments)
        merged = segments.filter_map(&:tool_calls).reduce({}, :merge)
        merged.empty? ? nil : merged
      end
    end
  end
end
