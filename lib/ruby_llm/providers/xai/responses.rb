# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # xAI's dialect of the OpenAI Responses API, the primary protocol for
      # Grok models. Usage counts agentic tool activity.
      class Responses < Protocols::Responses
        include XAI::ReportedCost
        include XAI::Images
        include XAI::Models
        include XAI::Speech
        include XAI::Transcription
        include XAI::Videos
        include Protocols::XAI::Tokenization
        include Protocols::Responses::Compaction
        include Protocols::XAI::StreamingTranscription

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } },
          x_search: { tool: { type: 'x_search' } },
          code_execution: { tool: { type: 'code_execution' } },
          code_interpreter: { tool: { type: 'code_interpreter' } },
          file_search: { tool: { type: 'file_search' } },
          collections_search: { tool: { type: 'file_search' } },
          image_generation: { tool: { type: 'image_generation' } },
          mcp: Protocols::Responses::SERVER_TOOL_ALIASES.fetch(:mcp)
        }.freeze

        SERVER_TOOL_USAGE_NAMES = { 'code_interpreter' => 'code_execution' }.freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def parse_usage(usage)
          super.merge(reported_cost: reported_cost(usage))
        end

        private

        # Each *_calls detail counts one tool; the totals and the X Search
        # fetch counts beside them do not.
        def parse_server_tool_use(response)
          details = response.dig('usage', 'server_side_tool_usage_details').to_h
          details.filter_map do |counter, count|
            tool = counter[/\A(.+)_calls\z/, 1]
            ["#{SERVER_TOOL_USAGE_NAMES.fetch(tool, tool)}_requests", count] if tool
          end.to_h
        end
      end
    end
  end
end
